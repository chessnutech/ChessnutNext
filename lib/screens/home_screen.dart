import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/android_accessibility_vision_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/daily_claim_service.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/chessnut_motion.dart';
import 'daily_tasks_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.onNavigate,
    required this.boardConnected,
    required this.boardModel,
    required this.dailyClaimService,
    required this.apiClient,
    this.engineBuildCompletedBubble = false,
    this.walletBalanceSnapshot,
    this.dailyCheckInClaimed,
    this.claimedDailyTaskKeys = const <String>{},
    this.onWalletBalanceLoaded,
    this.continueRecord,
    this.continueBotRecord,
    this.continueOnlineRecord,
    this.continueOnlineRecords = const [],
    this.continueLocalRecords = const [],
    this.onContinueRecord,
    this.onDismissContinueRecord,
    this.visionEnabled = false,
    this.onVisionEnabledChanged,
    this.accessibilityVisionService,
    this.isChessnutClockDevice = false,
    this.isChessnutEvo2Device = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final bool boardConnected;
  final ChessnutBoardModel boardModel;
  final DailyClaimService dailyClaimService;
  final ChessnutApiClient apiClient;
  final bool engineBuildCompletedBubble;
  final WalletBalance? walletBalanceSnapshot;
  final bool? dailyCheckInClaimed;
  final Set<String> claimedDailyTaskKeys;
  final ValueChanged<WalletBalance>? onWalletBalanceLoaded;
  final GameRecord? continueRecord;
  final GameRecord? continueBotRecord;
  final GameRecord? continueOnlineRecord;
  final List<GameRecord> continueOnlineRecords;
  final List<GameRecord> continueLocalRecords;
  final Future<void> Function(GameRecord record)? onContinueRecord;
  final ValueChanged<GameRecord>? onDismissContinueRecord;
  final bool visionEnabled;
  final FutureOr<void> Function(bool enabled)? onVisionEnabledChanged;
  final AccessibilityVisionBridge? accessibilityVisionService;
  final bool isChessnutClockDevice;
  final bool isChessnutEvo2Device;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool walletLoading = false;
  WalletBalance? walletBalance;

  WalletBalance? get _effectiveWalletBalance =>
      walletBalance ?? widget.walletBalanceSnapshot;

  DailyClaimStatus get dailyStatus {
    final remoteClaimed =
        widget.dailyCheckInClaimed ?? _effectiveWalletBalance?.claimedToday;
    if (_signedIn && remoteClaimed != null) {
      final claimed = remoteClaimed;
      return DailyClaimStatus(
        canClaim: !claimed,
        label: claimed ? 'Claimed' : 'Claim',
        nextAvailableAt: DateTime.now(),
      );
    }
    return widget.dailyClaimService.status();
  }

  bool get _signedIn => widget.apiClient.session != null;

  int get _dailyTaskCompletedCount {
    final status = dailyStatus;
    final workflowClaims = _signedIn
        ? {
            ...widget.claimedDailyTaskKeys,
            ...?_effectiveWalletBalance?.claimedTaskKeys,
          }
        : const <String>{};
    return (status.canClaim ? 0 : 1) +
        dailyTaskVisibleClaimCount(workflowClaims);
  }

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiClient.session != widget.apiClient.session) {
      walletBalance = null;
      _loadWalletBalance();
    }
  }

  Future<void> _loadWalletBalance() async {
    if (!_signedIn || walletLoading) return;
    setState(() => walletLoading = true);
    final result = await widget.apiClient.walletBalance();
    if (!mounted) return;
    setState(() {
      walletLoading = false;
      walletBalance = result.isSuccess ? result.data : null;
    });
    final balance = result.data;
    if (result.isSuccess && balance != null) {
      widget.onWalletBalanceLoaded?.call(balance);
    }
  }

  void _openGuestSignInPrompt(String feature) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.lock_rounded,
        title: 'Sign in or create an account',
        subtitle: '$feature sync after you sign in.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Stay as guest'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onNavigate('Auth');
              },
              child: const Text('Sign in / register'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVisionToggle() async {
    final callback = widget.onVisionEnabledChanged;
    if (callback == null) return;
    final nextEnabled = !widget.visionEnabled;
    if (nextEnabled) {
      final accessibilityService = widget.accessibilityVisionService ??
          const AndroidAccessibilityVisionService();
      final accessibilityRunning =
          await accessibilityService.isAccessibilityRunning();
      if (!mounted) return;
      if (!accessibilityRunning) {
        await _showVisionAccessibilityPrompt(accessibilityService);
        return;
      }
      final confirmed = await showDialog<bool>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.62),
            builder: (dialogContext) => AppDialogShell(
              icon: Icons.visibility_rounded,
              title: 'Enable Chessnut Vision?',
              subtitle:
                  'Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.',
              actions: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('Enable Vision'),
                  ),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }
    await Future<void>.sync(() => callback(nextEnabled));
    if (!mounted || !nextEnabled) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Chessnut Vision is now active.')),
      );
  }

  Future<void> _showVisionAccessibilityPrompt(
    AccessibilityVisionBridge accessibilityService,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.settings_accessibility_rounded,
        title: 'Turn on Chessnut Vision in Accessibility',
        subtitle:
            'Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await accessibilityService.openAccessibilitySettings();
              },
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Settings'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = dailyStatus;
    final signedIn = _signedIn;
    final viewport = MediaQuery.sizeOf(context);
    final androidPhoneLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        !widget.isChessnutEvo2Device &&
        viewport.width > viewport.height &&
        viewport.width < 1000 &&
        viewport.height < 600;
    final windowsLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        viewport.width > viewport.height;
    final showVisionToggle = defaultTargetPlatform == TargetPlatform.android &&
        widget.onVisionEnabledChanged != null;
    return ResponsivePage(
      compactLandscapeOverride: androidPhoneLandscape,
      disableCompactLandscape: windowsLandscape,
      children: (context, spec) {
        final macOsDesktop =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
        final compactLandscape = spec.compactLandscape && !macOsDesktop;
        final windowsWide = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            spec.canSplit &&
            spec.width > spec.height;
        final desktopWide = windowsWide || macOsDesktop;
        final homeSpacing = compactLandscape ? 6.0 : spec.gutter;
        final desktopHeroHeight = desktopWide
            ? (spec.height * (macOsDesktop ? 0.42 : 0.49))
                .clamp(240.0, 440.0)
                .toDouble()
            : null;
        final continueRecords = _continueRecords();
        final continueNotice =
            continueRecords.isEmpty || widget.onContinueRecord == null
                ? null
                : _ContinueGamesNotice(
                    key: const ValueKey('home-continue-notice'),
                    count: continueRecords.length,
                    onTap: () => _showContinueGamesDialog(continueRecords),
                  );
        final hidePhysicalBoardConnectionUi = widget.isChessnutEvo2Device;
        final Widget? hero = hidePhysicalBoardConnectionUi
            ? null
            : GlassPanel(
                key: const ValueKey('home-board-hero'),
                padding: EdgeInsets.zero,
                onTap: widget.boardConnected
                    ? () => widget.onNavigate('BoardSettings')
                    : () => widget.onNavigate('ConnectBoard'),
                child: widget.boardConnected
                    ? BoardReadyHero(
                        onSettings: () => widget.onNavigate('BoardSettings'),
                        boardModel: widget.boardModel,
                        expanded: spec.expanded || windowsWide,
                        compactLandscape: compactLandscape,
                        expandedHeight: desktopHeroHeight,
                      )
                    : BoardDisconnectedHero(
                        onConnect: () => widget.onNavigate('ConnectBoard'),
                        expanded: spec.expanded || windowsWide,
                        compactLandscape: compactLandscape,
                        expandedHeight: desktopHeroHeight,
                        compactDesktop: macOsDesktop && spec.width < 1200,
                      ),
              );
        final engineTile = ActionTile(
          key: const ValueKey('home-action-engine'),
          title: 'Engine',
          subtitle:
              widget.engineBuildCompletedBubble ? 'Report ready' : 'LC0 lab',
          icon: Icons.bolt_rounded,
          badge: widget.engineBuildCompletedBubble,
          compactLandscapeProminent: false,
          compactLandscapeOverride: androidPhoneLandscape,
          disableCompactLandscape: windowsLandscape,
          onTap: () => widget.onNavigate('Engine'),
        );
        final desktopTrailingWidth = desktopWide
            ? (spec.width - spec.horizontalPadding * 2 - homeSpacing) * 7 / 12
            : 0.0;
        final desktopTileWidth =
            desktopWide ? (desktopTrailingWidth - 20) / 3 : 0.0;
        final desktopTileHeight = desktopWide
            ? (spec.height * (macOsDesktop ? 0.18 : 0.20))
                .clamp(macOsDesktop ? 96.0 : 132.0, 196.0)
                .toDouble()
            : 0.0;
        final actionGrid = ResponsiveGrid(
          minTileWidth: desktopWide
              ? (macOsDesktop ? 120 : 140)
              : compactLandscape
                  ? 168
                  : (spec.canSplit ? 142 : 154),
          maxColumns: desktopWide
              ? 3
              : compactLandscape
                  ? 2
                  : (spec.expanded ? 4 : 2),
          spacing: compactLandscape ? 6 : 10,
          childAspectRatio: desktopWide
              ? desktopTileWidth / desktopTileHeight
              : compactLandscape
                  ? (androidPhoneLandscape ? 3.8 : 5.2)
                  : (spec.canSplit ? 1.26 : 1.38),
          children: [
            ActionTile(
              key: const ValueKey('home-action-play'),
              title: 'Play',
              subtitle: 'Online / bot',
              icon: Icons.play_arrow_rounded,
              selected: true,
              compactLandscapeProminent: false,
              compactLandscapeOverride: androidPhoneLandscape,
              disableCompactLandscape: windowsLandscape,
              onTap: () => widget.onNavigate('Setup'),
            ),
            ActionTile(
              key: const ValueKey('home-action-career'),
              title: 'Career',
              subtitle: 'ELO journey',
              icon: Icons.military_tech_rounded,
              compactLandscapeProminent: false,
              compactLandscapeOverride: androidPhoneLandscape,
              disableCompactLandscape: windowsLandscape,
              onTap: signedIn
                  ? () => widget.onNavigate('Career')
                  : () => _openGuestSignInPrompt('Career Mode'),
            ),
            ActionTile(
              key: const ValueKey('home-action-analysis'),
              title: 'Analysis',
              subtitle: 'Game review',
              icon: Icons.analytics_rounded,
              compactLandscapeProminent: false,
              compactLandscapeOverride: androidPhoneLandscape,
              disableCompactLandscape: windowsLandscape,
              onTap: () => widget.onNavigate('Analysis'),
            ),
            ActionTile(
              key: const ValueKey('home-action-training'),
              title: 'Practice',
              subtitle: 'Puzzle / lesson',
              icon: Icons.school_rounded,
              compactLandscapeProminent: false,
              compactLandscapeOverride: androidPhoneLandscape,
              disableCompactLandscape: windowsLandscape,
              onTap: () => widget.onNavigate('Training'),
            ),
            ActionTile(
              key: const ValueKey('home-action-records'),
              title: 'Records',
              subtitle: 'Game history',
              icon: Icons.history_rounded,
              compactLandscapeProminent: false,
              compactLandscapeOverride: androidPhoneLandscape,
              disableCompactLandscape: windowsLandscape,
              onTap: () => widget.onNavigate('Records'),
            ),
            ChessnutAttentionBorder(
              active: widget.engineBuildCompletedBubble,
              borderRadius: 14,
              child: engineTile,
            ),
          ],
        );
        final actions = compactLandscape
            ? SectionColumn(
                spacing: 6,
                children: [
                  if (continueNotice != null) continueNotice,
                  actionGrid,
                  DailyTasksEntryCard(
                    status: status,
                    completed: _dailyTaskCompletedCount,
                    locked: !signedIn,
                    onTap: signedIn
                        ? () => widget.onNavigate('DailyTasks')
                        : () => _openGuestSignInPrompt('Daily tasks'),
                  ),
                  _ActivityStrip(
                    onNavigate: widget.onNavigate,
                    compact: compactLandscape,
                  ),
                ],
              )
            : SectionColumn(
                spacing: 10,
                children: [
                  actionGrid,
                  DailyTasksEntryCard(
                    status: status,
                    completed: _dailyTaskCompletedCount,
                    locked: !signedIn,
                    onTap: signedIn
                        ? () => widget.onNavigate('DailyTasks')
                        : () => _openGuestSignInPrompt('Daily tasks'),
                  ),
                  _ActivityStrip(
                    onNavigate: widget.onNavigate,
                    compact: compactLandscape,
                  ),
                ],
              );

        final headerTitle = widget.isChessnutClockDevice
            ? 'Chessnut Companion'
            : widget.isChessnutEvo2Device
                ? 'Chessnut EVO2'
                : 'Chessnut';
        return [
          ScreenHeader(
            title: headerTitle,
            titleKey: const ValueKey('home-header-title'),
            titleMaxLines: 1,
            titleOverflow: TextOverflow.visible,
            subtitle: hidePhysicalBoardConnectionUi
                ? null
                : widget.boardConnected
                    ? 'Board ready'
                    : 'Board not connected',
            compactTrailingFraction: showVisionToggle ? 0.52 : 0.34,
            reservePinnedTrailingWidth: false,
            trailing: showVisionToggle
                ? _HomeHeaderActions(
                    visionEnabled: widget.visionEnabled,
                    onVisionTap: _handleVisionToggle,
                  )
                : null,
          ),
          SizedBox(height: spec.gutter),
          if (compactLandscape && hero != null)
            _CompanionLandscapeHomeLayout(
              key: androidPhoneLandscape
                  ? const ValueKey('home-android-phone-landscape')
                  : null,
              spacing: homeSpacing,
              height: spec.heightAfterHeader(),
              hero: hero,
              actions: actions,
            )
          else if (compactLandscape)
            SizedBox(
              height: spec.heightAfterHeader(),
              child: _CompanionActionsScrollView(child: actions),
            )
          else
            ResponsiveSplit(
              breakpoint: 860,
              spacing: homeSpacing,
              leadingFlex: desktopWide ? 5 : 7,
              trailingFlex: desktopWide ? 7 : 6,
              leading: KeyedSubtree(
                key: const ValueKey('home-desktop-leading-column'),
                child: SectionColumn(
                  spacing: 10,
                  children: [
                    if (hero != null) hero,
                    if (continueNotice != null) continueNotice,
                    if (!hidePhysicalBoardConnectionUi &&
                        continueNotice == null &&
                        !widget.boardConnected)
                      const _ConnectionHintCard(),
                  ],
                ),
              ),
              trailing: KeyedSubtree(
                key: const ValueKey('home-desktop-actions-column'),
                child: actions,
              ),
            ),
        ];
      },
    );
  }

  List<GameRecord> _continueRecords() {
    final onlineRecords = <GameRecord>[
      ...widget.continueOnlineRecords,
      if (widget.continueOnlineRecords.isEmpty &&
          widget.continueOnlineRecord != null)
        widget.continueOnlineRecord!,
      if (widget.continueOnlineRecords.isEmpty &&
          widget.continueOnlineRecord == null &&
          (widget.continueRecord?.canContinueLichessGame ?? false))
        widget.continueRecord!,
    ];
    final localRecords = widget.continueLocalRecords.isNotEmpty
        ? widget.continueLocalRecords
        : <GameRecord>[
            if (widget.continueBotRecord != null) widget.continueBotRecord!,
            if (widget.continueRecord?.canContinueBotGame ?? false)
              widget.continueRecord!,
            if (widget.continueRecord?.canContinueOtbGame ?? false)
              widget.continueRecord!,
          ];
    final keys = <String>{
      for (final record in onlineRecords) _continueRecordIdentity(record),
    };
    return [
      ...onlineRecords,
      for (final record in localRecords)
        if (record.canContinueGame && keys.add(_continueRecordIdentity(record)))
          record,
    ];
  }

  String _continueRecordIdentity(GameRecord record) {
    if (record.canContinueLichessGame) {
      return 'lichess:${record.lichessGameId.toLowerCase()}';
    }
    final pgnId = record.pgnId;
    if (pgnId != null) return 'pgn:$pgnId';
    return 'pgn:${record.playMode}:${record.pgn.hashCode}';
  }

  Future<void> _showContinueGamesDialog(List<GameRecord> records) async {
    if (records.isEmpty || widget.onContinueRecord == null) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) {
        var visibleRecords = List<GameRecord>.of(records);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialogShell(
              icon: Icons.notifications_active_rounded,
              title: 'Continue game',
              actions: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final record in visibleRecords) ...[
                    _ContinueGameCard(
                      key: ValueKey(
                        record.canContinueLichessGame
                            ? 'home-continue-card-online-${record.lichessGameId}'
                            : 'home-continue-card-${record.playMode}-${record.pgnId ?? record.pgn.hashCode}',
                      ),
                      record: record,
                      onContinue: () async {
                        Navigator.of(dialogContext).pop();
                        await widget.onContinueRecord!(record);
                      },
                      onDismiss: widget.onDismissContinueRecord == null
                          ? null
                          : () {
                              final next = visibleRecords
                                  .where((item) => item != record)
                                  .toList(growable: false);
                              widget.onDismissContinueRecord!(record);
                              if (next.isEmpty) {
                                Navigator.of(dialogContext).pop();
                              } else {
                                setDialogState(() => visibleRecords = next);
                              }
                            },
                      compact: false,
                      isChessnutClockDevice: widget.isChessnutClockDevice,
                    ),
                    if (record != visibleRecords.last)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CompanionLandscapeHomeLayout extends StatefulWidget {
  const _CompanionLandscapeHomeLayout({
    required this.spacing,
    required this.height,
    required this.hero,
    required this.actions,
    super.key,
  });

  final double spacing;
  final double height;
  final Widget hero;
  final Widget actions;

  @override
  State<_CompanionLandscapeHomeLayout> createState() =>
      _CompanionLandscapeHomeLayoutState();
}

class _CompanionLandscapeHomeLayoutState
    extends State<_CompanionLandscapeHomeLayout> {
  final GlobalKey _actionsContentKey = GlobalKey();
  double? _actionsContentHeight;

  void _measureActions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _actionsContentKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;
      final nextHeight = renderBox.size.height;
      if ((_actionsContentHeight ?? -1) == nextHeight) return;
      setState(() => _actionsContentHeight = nextHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    _measureActions();
    final matchedHeight = (_actionsContentHeight ?? widget.height)
        .clamp(0.0, widget.height)
        .toDouble();
    return SizedBox(
      height: matchedHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: widget.hero),
          SizedBox(width: widget.spacing),
          Expanded(
            flex: 7,
            child: KeyedSubtree(
              key: const ValueKey('home-companion-actions-viewport'),
              child: _CompanionActionsScrollView(
                child: KeyedSubtree(
                  key: _actionsContentKey,
                  child: widget.actions,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionActionsScrollView extends StatefulWidget {
  const _CompanionActionsScrollView({required this.child});

  final Widget child;

  @override
  State<_CompanionActionsScrollView> createState() =>
      _CompanionActionsScrollViewState();
}

class _CompanionActionsScrollViewState
    extends State<_CompanionActionsScrollView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const ValueKey('home-companion-actions-scroll'),
        controller: _controller,
        child: widget.child,
      ),
    );
  }
}

class BoardDisconnectedHero extends StatelessWidget {
  const BoardDisconnectedHero({
    required this.onConnect,
    this.expanded = false,
    this.compactLandscape = false,
    this.expandedHeight,
    this.compactDesktop = false,
    super.key,
  });

  final VoidCallback onConnect;
  final bool expanded;
  final bool compactLandscape;
  final double? expandedHeight;
  final bool compactDesktop;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final classic = tokens.visualTheme == ChessnutVisualTheme.classic;
    final lowCost = isCompactLandscapeDevice(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.panelRadius),
      child: SizedBox(
        height: compactLandscape
            ? double.infinity
            : (expanded ? expandedHeight ?? 316 : 218),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: classic
                    ? (dark ? const Color(0xFF211811) : const Color(0xFFFFFCF4))
                    : (dark
                        ? const Color(0xFF0B1220)
                        : const Color(0xFFF7FBFD)),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BoardDisconnectedPainter(
                    primary: scheme.primary,
                    secondary: scheme.secondary,
                    dark: dark,
                    lowCost: lowCost,
                    compactDesktop: compactDesktop,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: compactLandscape || compactDesktop ? 10 : 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pair your physical board',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Turn on Bluetooth and keep the board close.',
                    maxLines: compactLandscape ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(
                    height: compactLandscape || compactDesktop ? 6 : 12,
                  ),
                  PrimaryButton(
                    label: 'Connect',
                    icon: Icons.bluetooth_searching_rounded,
                    onPressed: onConnect,
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

class BoardReadyHero extends StatelessWidget {
  const BoardReadyHero({
    required this.onSettings,
    required this.boardModel,
    this.expanded = false,
    this.compactLandscape = false,
    this.expandedHeight,
    super.key,
  });

  final VoidCallback onSettings;
  final ChessnutBoardModel boardModel;
  final bool expanded;
  final bool compactLandscape;
  final double? expandedHeight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final classic = tokens.visualTheme == ChessnutVisualTheme.classic;
    final lowCost = isCompactLandscapeDevice(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.panelRadius),
      child: SizedBox(
        height: compactLandscape
            ? double.infinity
            : (expanded ? expandedHeight ?? 316 : 178),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: classic
                    ? (dark ? const Color(0xFF211811) : const Color(0xFFFFFCF4))
                    : (dark
                        ? const Color(0xFF0B1220)
                        : const Color(0xFFF7FBFD)),
              ),
            ),
            Positioned.fill(
              child: _ConnectedBoardRender(
                expanded: expanded,
                child: Image.asset(
                  boardModel.imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    boardModel.fallbackImageAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: dark ? 0.02 : 0.00),
                      Colors.black.withValues(alpha: dark ? 0.24 : 0.08),
                    ],
                    stops: const [0, 0.56, 1],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BoardReadyAccentPainter(
                    primary: scheme.primary,
                    secondary: scheme.secondary,
                    dark: dark,
                    lowCost: lowCost,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: compactLandscape ? 12 : 15,
              child: _BoardStatusChip(
                icon: Icons.sensors_rounded,
                label: 'Board online',
                color: scheme.primary,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: compactLandscape ? 10 : 14,
              child: _ConnectedBoardSummary(
                onSettings: onSettings,
                boardModel: boardModel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedBoardRender extends StatelessWidget {
  const _ConnectedBoardRender({
    required this.child,
    required this.expanded,
  });

  final Widget child;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: expanded ? const Alignment(0, -0.16) : Alignment.topCenter,
      child: FractionallySizedBox(
        widthFactor: expanded ? 0.74 : 0.92,
        heightFactor: expanded ? 0.72 : 0.62,
        child: Padding(
          padding: EdgeInsets.only(top: expanded ? 28 : 14),
          child: child,
        ),
      ),
    );
  }
}

class _BoardDisconnectedPainter extends CustomPainter {
  const _BoardDisconnectedPainter({
    required this.primary,
    required this.secondary,
    required this.dark,
    this.lowCost = false,
    this.compactDesktop = false,
  });

  final Color primary;
  final Color secondary;
  final bool dark;
  final bool lowCost;
  final bool compactDesktop;

  @override
  void paint(Canvas canvas, Size size) {
    final classic = primary == ChessnutTheme.classicGreen ||
        primary == ChessnutTheme.classicGold;
    final boardSize = (size.shortestSide *
            (compactDesktop
                ? 0.38
                : size.width > 520
                    ? 0.70
                    : 0.58))
        .clamp(64.0, size.height * (compactDesktop ? 0.34 : 0.52));
    final boardRect = Rect.fromCenter(
      center: Offset(
        size.width * 0.50,
        size.height * (compactDesktop ? 0.25 : 0.35),
      ),
      width: boardSize,
      height: boardSize,
    );
    if (!lowCost) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.28 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          boardRect.translate(0, 12),
          const Radius.circular(18),
        ),
        shadowPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(18)),
      Paint()
        ..color = classic
            ? (dark ? const Color(0xFF2A2117) : const Color(0xFFFFF8EA))
            : (dark ? const Color(0xFF111827) : Colors.white),
    );

    final inner = boardRect.deflate(10);
    final tile = inner.width / 8;
    final lightSquare = classic
        ? (dark ? const Color(0xFFBFA46E) : const Color(0xFFF1D9A9))
        : (dark ? const Color(0xFFCBD5E1) : const Color(0xFFF8FAFC));
    final darkSquare = classic
        ? (dark ? const Color(0xFF6E4B2A) : const Color(0xFF9B6B3D))
        : (dark ? const Color(0xFF334155) : const Color(0xFFD7E1EA));
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        canvas.drawRect(
          Rect.fromLTWH(
            inner.left + file * tile,
            inner.top + rank * tile,
            tile,
            tile,
          ),
          Paint()..color = (rank + file).isEven ? lightSquare : darkSquare,
        );
      }
    }

    final center = Offset(
      size.width * 0.50,
      size.height * (compactDesktop ? 0.25 : 0.35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: boardSize * 0.36,
          height: boardSize * 0.36,
        ),
        const Radius.circular(18),
      ),
      Paint()..color = dark ? const Color(0xE6020617) : const Color(0xEFFFFFFF),
    );

    final ringPaint = Paint()
      ..color = secondary.withValues(alpha: dark ? 0.28 : 0.22)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: boardSize * 0.30),
      -0.74,
      1.48,
      false,
      ringPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: boardSize * 0.42),
      2.40,
      1.10,
      false,
      Paint()
        ..color = primary.withValues(alpha: dark ? 0.20 : 0.17)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final markSize = boardSize * 0.09;
    final markPaint = Paint()
      ..color = secondary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(center.dx, center.dy - markSize * 1.6)
      ..lineTo(center.dx, center.dy + markSize * 1.6)
      ..lineTo(center.dx + markSize, center.dy + markSize)
      ..lineTo(center.dx - markSize, center.dy)
      ..lineTo(center.dx + markSize, center.dy - markSize)
      ..close();
    canvas.drawPath(path, markPaint);

    canvas.drawLine(
      center.translate(-markSize * 1.9, markSize * 1.8),
      center.translate(markSize * 1.9, -markSize * 1.8),
      Paint()
        ..color = primary.withValues(alpha: dark ? 0.90 : 0.82)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BoardDisconnectedPainter oldDelegate) {
    return primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        dark != oldDelegate.dark ||
        lowCost != oldDelegate.lowCost ||
        compactDesktop != oldDelegate.compactDesktop;
  }
}

class _BoardReadyAccentPainter extends CustomPainter {
  const _BoardReadyAccentPainter({
    required this.primary,
    required this.secondary,
    required this.dark,
    this.lowCost = false,
  });

  final Color primary;
  final Color secondary;
  final bool dark;
  final bool lowCost;

  @override
  void paint(Canvas canvas, Size size) {
    final railPaint = Paint()
      ..color = secondary.withValues(alpha: dark ? 0.22 : 0.14)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.30),
      Offset(size.width * 0.30, size.height * 0.48),
      railPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.48),
      Offset(size.width * 0.92, size.height * 0.72),
      railPaint,
    );

    final ledPaint = Paint()..color = primary;
    for (final point in [
      Offset(size.width * 0.43, size.height * 0.58),
      Offset(size.width * 0.50, size.height * 0.60),
      Offset(size.width * 0.57, size.height * 0.58),
    ]) {
      canvas.drawCircle(point, 3.2, ledPaint);
      canvas.drawCircle(
          point, 8.5, Paint()..color = primary.withValues(alpha: 0.12));
    }

    final scrim = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: dark ? 0.22 : 0.06),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), scrim);
  }

  @override
  bool shouldRepaint(covariant _BoardReadyAccentPainter oldDelegate) {
    return primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        dark != oldDelegate.dark ||
        lowCost != oldDelegate.lowCost;
  }
}

class _ConnectedBoardSummary extends StatelessWidget {
  const _ConnectedBoardSummary({
    required this.onSettings,
    required this.boardModel,
  });

  final VoidCallback onSettings;
  final ChessnutBoardModel boardModel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tokens = ChessnutTheme.tokensOf(context);
    return Row(
      children: [
        Expanded(
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            borderRadius: tokens.controlRadius,
            tint: tokens.panelFill.withValues(alpha: dark ? 0.82 : 0.92),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${boardModel.displayName} connected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GlassPanel(
          key: const ValueKey('home-board-settings-button'),
          onTap: onSettings,
          padding: const EdgeInsets.all(10),
          borderRadius: tokens.controlRadius,
          tint: tokens.panelFill.withValues(alpha: dark ? 0.82 : 0.92),
          child: Icon(
            Icons.settings_input_component_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _BoardStatusChip extends StatelessWidget {
  const _BoardStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      borderRadius: 999,
      tint: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xB80F172A)
          : const Color(0xEFFFFFFF),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
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

class _ContinueGamesNotice extends StatelessWidget {
  const _ContinueGamesNotice({
    required this.count,
    required this.onTap,
    super.key,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      borderRadius: 13,
      tint: scheme.primary.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Continue game',
                key: ValueKey('home-continue-notice-title'),
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 28),
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$count',
                key: const ValueKey('home-continue-notice-count'),
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ContinueGameCard extends StatefulWidget {
  const _ContinueGameCard({
    required this.record,
    required this.onContinue,
    this.onDismiss,
    this.compact = false,
    this.isChessnutClockDevice = false,
    super.key,
  });

  final GameRecord record;
  final FutureOr<void> Function() onContinue;
  final VoidCallback? onDismiss;
  final bool compact;
  final bool isChessnutClockDevice;
  static const double _minActionWidth = 96;

  @override
  State<_ContinueGameCard> createState() => _ContinueGameCardState();
}

class _ContinueGameCardState extends State<_ContinueGameCard> {
  bool continuing = false;

  Future<void> _continue() async {
    if (continuing) return;
    setState(() => continuing = true);
    try {
      await Future<void>.sync(widget.onContinue);
    } finally {
      if (mounted) setState(() => continuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Keep the continue cards readable on every native target. The compact
    // action layout was originally Android-only, which left the same dialog
    // cramped on iOS, desktop, and Chessnut Clock builds.
    final useCompactActions = !kIsWeb;
    final record = widget.record;
    final isLichess = record.canContinueLichessGame;
    final isOtb = record.canContinueOtbGame;
    final title = isLichess
        ? 'Continue online game'
        : isOtb
            ? 'Continue OTB game'
            : 'Continue bot game';
    final keySuffix = isLichess
        ? 'online-${record.lichessGameId}'
        : isOtb
            ? 'otb'
            : 'bot';
    final subtitle =
        isLichess ? _lichessContinueSubtitle(record) : record.title;
    if (widget.compact) {
      return GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        borderRadius: 12,
        tint: scheme.primary.withValues(alpha: 0.08),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLichess
                    ? Icons.public_rounded
                    : isOtb
                        ? Icons.groups_rounded
                        : Icons.play_arrow_rounded,
                color: scheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    key: ValueKey('home-continue-title-$keySuffix'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 34,
              child: FilledButton(
                key: ValueKey('home-continue-action-$keySuffix'),
                onPressed: continuing ? null : _continue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(72, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: continuing
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resume'),
              ),
            ),
            if (widget.onDismiss != null) ...[
              const SizedBox(width: 2),
              SizedBox.square(
                dimension: 34,
                child: IconButton(
                  tooltip: 'Ignore continue reminder',
                  onPressed: continuing ? null : widget.onDismiss,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return GlassPanel(
      padding: useCompactActions
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.all(12),
      borderRadius: 13,
      tint: scheme.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: useCompactActions ? 40 : 44,
            height: useCompactActions ? 40 : 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(
                useCompactActions ? 11 : 12,
              ),
            ),
            child: Icon(
              isLichess
                  ? Icons.public_rounded
                  : isOtb
                      ? Icons.groups_rounded
                      : Icons.play_arrow_rounded,
              color: scheme.primary,
              size: useCompactActions ? 22 : null,
            ),
          ),
          SizedBox(width: useCompactActions ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: ValueKey('home-continue-title-$keySuffix'),
                  // Keep the complete action context visible on narrow
                  // Android dialogs. Two lines are preferable to truncating
                  // every entry to an ambiguous “Continue …” label.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: useCompactActions ? 15 : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  key: ValueKey('home-continue-subtitle-$keySuffix'),
                  maxLines: useCompactActions ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(width: useCompactActions ? 8 : 10),
          if (useCompactActions)
            SizedBox(
              width: 96,
              height: 40,
              child: FilledButton(
                key: ValueKey('home-continue-action-$keySuffix'),
                onPressed: continuing ? null : _continue,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: SizedBox.square(
                          key: ValueKey('home-continue-icon-$keySuffix'),
                          dimension: 16,
                          child: continuing
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const Icon(Icons.play_arrow_rounded, size: 16),
                        ),
                      ),
                    ),
                    Center(
                      key: ValueKey(
                        'home-continue-label-center-$keySuffix',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            continuing ? 'Checking' : 'Resume',
                            key: ValueKey('home-continue-label-$keySuffix'),
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _ContinueGameCard._minActionWidth,
              ),
              child: FilledButton.icon(
                key: ValueKey('home-continue-action-$keySuffix'),
                onPressed: continuing ? null : _continue,
                icon: continuing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(continuing ? 'Checking' : 'Resume'),
              ),
            ),
          SizedBox(width: useCompactActions ? 2 : 4),
          if (useCompactActions)
            SizedBox.square(
              dimension: 40,
              child: IconButton(
                key: ValueKey('home-continue-dismiss-$keySuffix'),
                tooltip: 'Ignore continue reminder',
                onPressed: continuing ? null : widget.onDismiss,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded, size: 22),
              ),
            )
          else
            IconButton(
              key: ValueKey('home-continue-dismiss-$keySuffix'),
              tooltip: 'Ignore continue reminder',
              onPressed: continuing ? null : widget.onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }

  String _lichessContinueSubtitle(GameRecord record) {
    final opponent = record.opponentNameOverride.trim();
    final speed = record.speedOverride.trim();
    final detail = speed.isNotEmpty ? speed : record.timeLabel;
    if (opponent.isNotEmpty) {
      return detail.isEmpty || detail == '-'
          ? '$opponent · Lichess'
          : '$opponent · Lichess $detail';
    }
    return 'Lichess $detail'.trim();
  }
}

class _ConnectionHintCard extends StatelessWidget {
  const _ConnectionHintCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.info_outline_rounded, color: scheme.secondary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect before play',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'We will guide permissions and board pairing mode.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeaderActions extends StatelessWidget {
  const _HomeHeaderActions({
    required this.visionEnabled,
    required this.onVisionTap,
  });

  final bool visionEnabled;
  final VoidCallback onVisionTap;

  @override
  Widget build(BuildContext context) {
    return _VisionTogglePill(
      enabled: visionEnabled,
      onTap: onVisionTap,
    );
  }
}

class _VisionTogglePill extends StatelessWidget {
  const _VisionTogglePill({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = enabled ? scheme.primary : scheme.outline;
    return Tooltip(
      message: enabled ? 'Chessnut Vision is on' : 'Chessnut Vision is off',
      child: Semantics(
        key: const ValueKey('home-vision-toggle'),
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            borderRadius: 999,
            tint: accent.withValues(alpha: enabled ? 0.14 : 0.07),
            child: SizedBox(
              height: 28,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 15,
                    color: accent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Vision',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityStrip extends StatelessWidget {
  const _ActivityStrip({
    required this.onNavigate,
    this.compact = false,
  });

  final ValueChanged<String> onNavigate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StripButton(
            icon: Icons.manage_accounts_rounded,
            label: 'Account settings',
            compact: compact,
            onTap: () => onNavigate('Account'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StripButton(
            icon: Icons.settings_rounded,
            label: 'App settings',
            compact: compact,
            onTap: () => onNavigate('Settings'),
          ),
        ),
      ],
    );
  }
}

class _StripButton extends StatelessWidget {
  const _StripButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.secondary;
    return GlassPanel(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 9 : 12,
      ),
      borderRadius: 12,
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
