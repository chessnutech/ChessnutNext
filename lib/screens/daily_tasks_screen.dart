import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';

import '../services/chessnut_api_client.dart';
import '../services/daily_claim_service.dart';
import '../services/wallet_display.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/chessnut_celebration.dart';
import '../widgets/chessnut_motion.dart';

int dailyTaskRewardPoints(int points) {
  if (points <= 0) return 0;
  return points;
}

int get dailyCheckInRewardPoints =>
    dailyTaskSpecs.firstWhere((task) => task.key == 'check-in').points;

int dailyTaskVisibleClaimCount(Set<String> claimedTaskKeys) {
  final visibleKeys = dailyTaskSpecs.map((task) => task.key).toSet();
  return claimedTaskKeys.intersection(visibleKeys).length;
}

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({
    required this.onNavigate,
    required this.dailyClaimService,
    required this.apiClient,
    this.walletBalanceSnapshot,
    this.claimedDailyTaskKeys = const <String>{},
    this.onDailyTaskStateChanged,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final DailyClaimService dailyClaimService;
  final ChessnutApiClient apiClient;
  final WalletBalance? walletBalanceSnapshot;
  final Set<String> claimedDailyTaskKeys;
  final ValueChanged<DailyTaskStateSnapshot>? onDailyTaskStateChanged;

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  bool claimLoading = false;
  String? taskClaimLoadingKey;
  bool statusLoading = false;
  bool claimedInCurrentSession = false;
  late bool? remoteClaimedToday = widget.walletBalanceSnapshot?.claimedToday;
  int remoteDailyClaimPoints = dailyCheckInRewardPoints;
  late int? remoteWalletBalance = widget.walletBalanceSnapshot?.balance;
  late Set<String> claimedTaskKeys = {
    ...widget.claimedDailyTaskKeys,
    ...?widget.walletBalanceSnapshot?.claimedTaskKeys,
  };

  DailyClaimStatus get dailyStatus {
    if (widget.apiClient.session != null && remoteClaimedToday != null) {
      final claimed = remoteClaimedToday!;
      return DailyClaimStatus(
        canClaim: !claimed,
        label: claimed ? 'Claimed' : 'Claim',
        nextAvailableAt: DateTime.now(),
      );
    }
    return widget.dailyClaimService.status();
  }

  int get dailyClaimPoints => remoteDailyClaimPoints;
  int get dailyClaimRewardPoints =>
      dailyTaskRewardPoints(dailyCheckInRewardPoints);

  @override
  void initState() {
    super.initState();
    remoteDailyClaimPoints = dailyCheckInRewardPoints;
    _loadRemoteDailyClaimStatus();
  }

  @override
  void didUpdateWidget(covariant DailyTasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletBalanceSnapshot != widget.walletBalanceSnapshot ||
        oldWidget.claimedDailyTaskKeys != widget.claimedDailyTaskKeys) {
      final snapshot = widget.walletBalanceSnapshot;
      setState(() {
        remoteClaimedToday = snapshot?.claimedToday ?? remoteClaimedToday;
        remoteDailyClaimPoints = dailyCheckInRewardPoints;
        remoteWalletBalance = snapshot?.balance ?? remoteWalletBalance;
        claimedTaskKeys = {
          ...widget.claimedDailyTaskKeys,
          ...?snapshot?.claimedTaskKeys,
        };
      });
    }
  }

  Future<void> _loadRemoteDailyClaimStatus() async {
    if (widget.apiClient.session == null || statusLoading) return;
    setState(() => statusLoading = true);
    final result = await widget.apiClient.walletBalance();
    if (!mounted) return;
    setState(() {
      statusLoading = false;
      if (result.isSuccess && result.data != null) {
        remoteClaimedToday =
            result.data!.claimedToday || claimedInCurrentSession;
        remoteDailyClaimPoints = dailyCheckInRewardPoints;
        remoteWalletBalance = result.data!.balance;
        claimedTaskKeys = result.data!.claimedTaskKeys.toSet();
      }
    });
    if (result.isSuccess && result.data != null) {
      final staleAfterClaim =
          claimedInCurrentSession && !result.data!.claimedToday;
      widget.onDailyTaskStateChanged?.call(staleAfterClaim
          ? DailyTaskStateSnapshot(
              claimedToday: remoteClaimedToday ?? true,
              dailyClaimPoints: dailyCheckInRewardPoints,
              claimedTaskKeys: claimedTaskKeys,
            )
          : DailyTaskStateSnapshot.fromWalletBalance(
              result.data!,
              claimedOverride: remoteClaimedToday,
            ));
    }
  }

  Future<void> _claimDaily() async {
    if (claimLoading || !dailyStatus.canClaim) return;
    setState(() => claimLoading = true);

    var pointsAdded = dailyClaimRewardPoints;
    if (widget.apiClient.session != null) {
      final remoteResult = await widget.apiClient.claimDailyPoints(
        points: dailyClaimRewardPoints,
      );
      if (!mounted) return;
      if (!remoteResult.isSuccess || remoteResult.data == null) {
        setState(() => claimLoading = false);
        showAppFeedback(
          context,
          _dailyClaimErrorMessage(remoteResult.status),
          tone: AppFeedbackTone.error,
        );
        return;
      }
      pointsAdded = remoteResult.data!.pointsAdded;
      final claimedNow = remoteResult.data!.claimedToday || pointsAdded > 0;
      widget.dailyClaimService.claim();
      setState(() {
        claimLoading = false;
        remoteClaimedToday = claimedNow;
        claimedInCurrentSession = claimedNow;
        remoteWalletBalance = remoteResult.data!.balance;
      });
      widget.onDailyTaskStateChanged?.call(
        DailyTaskStateSnapshot(
          claimedToday: claimedNow,
          dailyClaimPoints: dailyCheckInRewardPoints,
          claimedTaskKeys: claimedTaskKeys,
          walletBalance: remoteResult.data!.balance,
        ),
      );
      showPointsBurst(
        context,
        '+$pointsAdded',
        message: 'Daily check-in +$pointsAdded points',
        walletCreditLabel: '+$pointsAdded',
      );
      return;
    }

    final result = widget.dailyClaimService.claim();
    if (!mounted) return;
    setState(() {
      claimLoading = false;
      claimedInCurrentSession = result.claimed;
      if (widget.apiClient.session != null && result.claimed) {
        remoteClaimedToday = true;
      }
    });
    if (result.claimed) {
      showPointsBurst(
        context,
        '+$pointsAdded',
        message: 'Daily check-in +$pointsAdded points',
        walletCreditLabel: '+$pointsAdded',
      );
    }
  }

  Future<void> _claimWorkflowTask(DailyTaskSpec task) async {
    if (task.key == 'check-in' || taskClaimLoadingKey != null) return;
    final route = task.route;
    if (route != null) widget.onNavigate(route);
  }

  @override
  Widget build(BuildContext context) {
    final status = dailyStatus;
    final completedCount =
        (status.canClaim ? 0 : 1) + dailyTaskVisibleClaimCount(claimedTaskKeys);
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Daily Tasks',
          subtitle: 'Complete daily activities to earn Chessnut points',
          leading: IconButton.filledTonal(
            key: const ValueKey('daily-tasks-back-button'),
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: _DailyTaskPointsBadge(balance: remoteWalletBalance),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 880,
          spacing: spec.gutter,
          leadingFlex: 5,
          trailingFlex: 6,
          leading: SectionColumn(
            spacing: 12,
            children: [
              _DailyTaskHero(
                completed: completedCount,
                total: dailyTaskSpecs.length,
              ),
              _DailyTaskStreakCard(
                status: status,
                loading: claimLoading,
                points: dailyClaimRewardPoints,
                onClaim: _claimDaily,
              ),
            ],
          ),
          trailing: SectionColumn(
            spacing: 10,
            children: [
              for (final task in dailyTaskSpecs)
                DailyTaskRow(
                  task: task,
                  claimed: task.key == 'check-in'
                      ? !status.canClaim
                      : claimedTaskKeys.contains(task.key),
                  loading: task.key == 'check-in'
                      ? claimLoading
                      : taskClaimLoadingKey == task.key,
                  pointsOverride:
                      task.key == 'check-in' ? dailyClaimRewardPoints : null,
                  actionLabel: _actionLabelFor(task, status),
                  onTap: () {
                    if (task.key == 'check-in') {
                      _claimDaily();
                      return;
                    }
                    _claimWorkflowTask(task);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _dailyClaimErrorMessage(ApiStatus status) {
    if (status.errorMessage == walletServiceUnavailableMessage) {
      return walletServiceUnavailableMessage;
    }
    return status.errorMessage ?? 'Daily check-in is unavailable right now.';
  }

  String _actionLabelFor(DailyTaskSpec task, DailyClaimStatus status) {
    if (task.key == 'check-in') {
      if (claimLoading) return '...';
      return AppStrings.of(context).t(status.label);
    }
    if (claimedTaskKeys.contains(task.key)) {
      return AppStrings.of(context).t('Done');
    }
    return AppStrings.of(context).t('Go');
  }
}

class DailyTaskStateSnapshot {
  const DailyTaskStateSnapshot({
    required this.claimedToday,
    required this.dailyClaimPoints,
    required this.claimedTaskKeys,
    this.walletBalance,
  });

  factory DailyTaskStateSnapshot.fromWalletBalance(
    WalletBalance balance, {
    bool? claimedOverride,
  }) {
    return DailyTaskStateSnapshot(
      claimedToday: claimedOverride ?? balance.claimedToday,
      dailyClaimPoints: dailyCheckInRewardPoints,
      claimedTaskKeys: balance.claimedTaskKeys.toSet(),
      walletBalance: balance.balance,
    );
  }

  final bool claimedToday;
  final int dailyClaimPoints;
  final Set<String> claimedTaskKeys;
  final int? walletBalance;
}

class DailyTaskSpec {
  const DailyTaskSpec({
    required this.key,
    required this.title,
    required this.points,
    required this.icon,
    required this.route,
    required this.description,
  });

  final String key;
  final String title;
  final int points;
  final IconData icon;
  final String? route;
  final String description;
}

const dailyTaskSpecs = [
  DailyTaskSpec(
    key: 'check-in',
    title: 'Check in',
    points: 100,
    icon: Icons.calendar_month_rounded,
    route: null,
    description: 'Claim once per day. Refreshes at local noon after 24 hours.',
  ),
  DailyTaskSpec(
    key: 'game',
    title: 'Finish one bot or online game',
    points: 20,
    icon: Icons.sports_esports_rounded,
    route: 'Setup',
    description: 'Play a complete Chessnut game with bot or online mode.',
  ),
  DailyTaskSpec(
    key: 'puzzle',
    title: 'Play one puzzle',
    points: 20,
    icon: Icons.extension_rounded,
    route: 'Training',
    description: 'Solve a tactical puzzle from the training area.',
  ),
  DailyTaskSpec(
    key: 'career',
    title: 'Complete one Career challenge',
    points: 20,
    icon: Icons.military_tech_rounded,
    route: 'Career',
    description: 'Finish a Career Mode challenge game.',
  ),
  DailyTaskSpec(
    key: 'share-report',
    title: 'Share one report',
    points: 20,
    icon: Icons.insert_chart_outlined_rounded,
    route: 'Analysis',
    description: 'Share a Standard or Grandeur report image.',
  ),
  DailyTaskSpec(
    key: 'analysis',
    title: 'Run one game analysis',
    points: 20,
    icon: Icons.analytics_rounded,
    route: 'Analysis',
    description: 'Review a PGN with Stockfish or Grandeur.',
  ),
];

class DailyTasksEntryCard extends StatelessWidget {
  const DailyTasksEntryCard({
    required this.status,
    required this.onTap,
    this.completed,
    this.locked = false,
    super.key,
  });

  final DailyClaimStatus status;
  final VoidCallback onTap;
  final int? completed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final completedCount = completed ?? (status.canClaim ? 0 : 1);
    final scheme = Theme.of(context).colorScheme;
    final compactLandscape = isCompactLandscapeDevice(context);
    final accent = locked ? scheme.outline : scheme.primary;
    final strings = AppStrings.of(context);
    final card = GlassPanel(
      key: ValueKey(
        locked ? 'home-daily-tasks-guest-locked' : 'home-daily-tasks-entry',
      ),
      onTap: onTap,
      padding: EdgeInsets.all(compactLandscape ? 10 : 12),
      borderRadius: 14,
      tint: accent.withValues(alpha: locked ? 0.045 : 0.055),
      child: Row(
        children: [
          Container(
            width: compactLandscape ? 38 : 44,
            height: compactLandscape ? 38 : 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              locked ? Icons.lock_rounded : Icons.task_alt_rounded,
              color: accent,
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
                        'Daily tasks',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TinyTaskBadge(
                      label: locked
                          ? strings.t('Sign in')
                          : strings.t(
                              '$completedCount/${dailyTaskSpecs.length} done',
                            ),
                    ),
                  ],
                ),
                SizedBox(height: compactLandscape ? 5 : 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: completedCount / dailyTaskSpecs.length,
                    color: accent,
                    backgroundColor: scheme.secondary.withValues(alpha: 0.13),
                  ),
                ),
                SizedBox(height: compactLandscape ? 5 : 7),
                Text(
                  locked
                      ? strings
                          .t('Sign in to claim points and keep your streak.')
                      : completedCount == dailyTaskSpecs.length
                          ? strings.t('All daily tasks completed.')
                          : status.canClaim
                              ? strings.t(
                                  'Check in and finish today\'s chess goals.',
                                )
                              : strings.t(
                                  'Progress synced. Keep the streak moving.',
                                ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            color: accent,
          ),
        ],
      ),
    );
    return ChessnutAttentionBorder(
      active: status.canClaim && !locked,
      borderRadius: 14,
      child: card,
    );
  }
}

class DailyTaskRow extends StatelessWidget {
  const DailyTaskRow({
    required this.task,
    required this.claimed,
    required this.loading,
    required this.actionLabel,
    required this.onTap,
    this.pointsOverride,
    super.key,
  });

  final DailyTaskSpec task;
  final bool claimed;
  final bool loading;
  final String actionLabel;
  final VoidCallback onTap;
  final int? pointsOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = claimed ? scheme.primary : scheme.secondary;
    final canClaim = task.key == 'check-in' && !claimed && !loading;
    final strings = AppStrings.of(context);
    final row = GlassPanel(
      key: ValueKey('daily-task-${task.key}'),
      onTap: claimed || loading ? null : onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      borderRadius: 14,
      tint: color.withValues(alpha: claimed ? 0.10 : 0.05),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              claimed ? Icons.check_rounded : task.icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  claimed ? strings.t('Completed today') : task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TinyTaskBadge(
                label:
                    '+${pointsOverride ?? dailyTaskRewardPoints(task.points)}',
                color: scheme.primary,
              ),
              const SizedBox(height: 7),
              TinyTaskBadge(
                label: claimed ? strings.t('Claimed') : actionLabel,
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
    return ChessnutAttentionBorder(
      active: canClaim,
      color: color,
      borderRadius: 14,
      child: row,
    );
  }
}

class TinyTaskBadge extends StatelessWidget {
  const TinyTaskBadge({
    required this.label,
    this.color,
    super.key,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: resolved.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: resolved.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: resolved,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DailyTaskHero extends StatelessWidget {
  const _DailyTaskHero({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      tint: scheme.primary.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.bolt_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completed / $total',
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'tasks completed today',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: completed / total,
              color: scheme.primary,
              backgroundColor: scheme.secondary.withValues(alpha: 0.13),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A compact daily loop for learning, playing, Career challenges, and reviews.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: tokens.visualTheme == ChessnutVisualTheme.classic
                          ? 0.78
                          : 0.72),
                ),
          ),
        ],
      ),
    );
  }
}

class _DailyTaskStreakCard extends StatelessWidget {
  const _DailyTaskStreakCard({
    required this.status,
    required this.loading,
    required this.points,
    required this.onClaim,
  });

  final DailyClaimStatus status;
  final bool loading;
  final int points;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: scheme.tertiary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.canClaim
                      ? strings.t('Check-in ready')
                      : strings.t('Checked in today'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              ChessnutPulseBadge(
                active: status.canClaim,
                child: TinyTaskBadge(
                  label: status.canClaim ? '+$points' : strings.t('Claimed'),
                  color: status.canClaim ? scheme.primary : scheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.canClaim
                ? strings.t(
                    'The check-in task refreshes at local noon, and still requires at least 24 hours since the last claim.',
                  )
                : strings.t(
                    'Come back after the next valid refresh window to claim again.',
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ChessnutShimmerAction(
            active: status.canClaim && !loading,
            child: FilledButton.icon(
              key: const ValueKey('daily-task-check-in-hero'),
              onPressed: status.canClaim && !loading ? onClaim : null,
              icon: Icon(
                loading ? Icons.sync_rounded : Icons.calendar_month_rounded,
              ),
              label: Text(
                loading ? 'Claiming...' : strings.t(status.label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTaskPointsBadge extends StatelessWidget {
  const _DailyTaskPointsBadge({required this.balance});

  final int? balance;

  @override
  Widget build(BuildContext context) {
    return TinyTaskBadge(
      label: balance == null
          ? '-- ${AppStrings.of(context).t('pts')}'
          : '${formatWalletPoints(balance!)} ${AppStrings.of(context).t('pts')}',
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

void showPointsBurst(
  BuildContext context,
  String label, {
  String? message,
  String? walletCreditLabel,
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            _PointsBurst(label: label, message: message),
            if (walletCreditLabel != null)
              _WalletCreditBurst(label: walletCreditLabel),
          ],
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1180), () {
    entry.remove();
  });
}

class _WalletCreditBurst extends StatelessWidget {
  const _WalletCreditBurst({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final effects = chessnutMotionEnabled(context);
    final top = MediaQuery.paddingOf(context).top +
        (isCompactLandscapeDevice(context) ? 10 : 18);
    final right = isCompactLandscapeDevice(context) ? 12.0 : 18.0;
    final duration =
        effects ? const Duration(milliseconds: 760) : Duration.zero;
    return Positioned(
      key: const ValueKey('wallet-credit-burst'),
      top: top,
      right: right,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final pop = value;
          final y = !effects
              ? 0.0
              : pop < 0.22
                  ? -16 * (pop / 0.22)
                  : -16 + 8 * ((pop - 0.22) / 0.78).clamp(0, 1);
          final scale = !effects
              ? 1.0
              : pop < 0.18
                  ? 0.72 + 0.42 * (pop / 0.18)
                  : 1.14 - 0.14 * ((pop - 0.18) / 0.82).clamp(0, 1);
          final opacity = !effects
              ? 1.0
              : pop < 0.12
                  ? pop / 0.12
                  : pop > 0.58
                      ? (1 - pop) / 0.42
                      : 1.0;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0).toDouble(),
            child: Transform.translate(
              offset: Offset(0, y.toDouble()),
              child: Transform.scale(scale: scale.toDouble(), child: child),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: tokens.visualTheme == ChessnutVisualTheme.classic
                ? scheme.tertiary.withValues(alpha: 0.96)
                : const Color(0xFFF5C542),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.72),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monetization_on_rounded,
                size: 15,
                color: tokens.visualTheme == ChessnutVisualTheme.classic
                    ? scheme.onTertiary
                    : const Color(0xFF3B2A00),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: tokens.visualTheme == ChessnutVisualTheme.classic
                      ? scheme.onTertiary
                      : const Color(0xFF3B2A00),
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsBurst extends StatelessWidget {
  const _PointsBurst({required this.label, this.message});

  final String label;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final positive = !label.startsWith('-');
    final tokens = ChessnutTheme.tokensOf(context);
    final classic = tokens.visualTheme == ChessnutVisualTheme.classic;
    final scheme = Theme.of(context).colorScheme;
    final positiveColors = classic
        ? [
            scheme.primary.withValues(alpha: 0.96),
            scheme.tertiary.withValues(alpha: 0.94),
          ]
        : const [Color(0xEFC8FF5F), Color(0xE657C1FF)];
    final negativeColors = classic
        ? const [Color(0xFFE1A06A), Color(0xFF9B3F2F)]
        : const [Color(0xEFFF6161), Color(0xDB8B80FF)];
    return Positioned(
      left: 0,
      right: 0,
      bottom: 86,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1180),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final opacity = value < 0.14
                ? value / 0.14
                : value > 0.76
                    ? (1 - value) / 0.24
                    : 1.0;
            final scale = value < 0.14
                ? 0.82 + (value / 0.14) * 0.26
                : 1.08 - (value * 0.14).clamp(0, 0.14);
            final y = value < 0.14
                ? 18 - (value / 0.14) * 18
                : -62 * ((value - 0.14) / 0.86).clamp(0, 1);
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0).toDouble(),
              child: Transform.translate(
                offset: Offset(0, y.toDouble()),
                child: Transform.scale(scale: scale.toDouble(), child: child),
              ),
            );
          },
          child: Center(
            child: Container(
              height: 46,
              constraints: const BoxConstraints(minWidth: 116),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: positive
                      ? (classic
                          ? scheme.tertiary.withValues(alpha: 0.52)
                          : const Color(0x94C8FF5F))
                      : (classic
                          ? const Color(0x99A33A2D)
                          : const Color(0x94FF6161)),
                ),
                gradient: LinearGradient(
                  colors: positive ? positiveColors : negativeColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: positive
                  ? ChessnutClaimCelebration(label: message ?? label)
                  : Text(
                      label,
                      style: TextStyle(
                        color: classic ? scheme.onPrimary : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
