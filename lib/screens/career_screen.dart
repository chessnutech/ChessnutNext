import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/chessnut_api_client.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';

class CareerScreen extends StatefulWidget {
  const CareerScreen({
    required this.onNavigate,
    required this.apiClient,
    required this.onLaunchCareerGame,
    this.rematchRequest = 0,
    this.excludedOpponentName = '',
    this.isChessnutClockDevice = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final ValueChanged<BotGameConfig> onLaunchCareerGame;
  final int rematchRequest;
  final String excludedOpponentName;
  final bool isChessnutClockDevice;

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  bool loading = true;
  int careerElo = 1200;
  String? errorMessage;
  bool hasLoadedCareerElo = false;
  // Maia 3 is enabled only after a successful network-backed career request.
  // This also covers cached-ELO sessions where the device is currently offline.
  bool networkAvailable = false;
  CareerRatingDelta? ratingDelta;
  int ratingDeltaToken = 0;
  Timer? ratingDeltaTimer;
  bool rematchStarted = false;

  @override
  void initState() {
    super.initState();
    final cachedElo = widget.apiClient.cachedCareerElo;
    if (cachedElo != null) {
      careerElo = cachedElo;
      hasLoadedCareerElo = true;
      loading = false;
    }
    unawaited(_loadCareer());
  }

  Future<void> _loadCareer() async {
    if (widget.apiClient.session == null) {
      setState(() {
        loading = false;
        careerElo = 1200;
        hasLoadedCareerElo = true;
        errorMessage = 'Sign in to sync your career progress.';
      });
      return;
    }
    if (!hasLoadedCareerElo || errorMessage != null) {
      setState(() {
        loading = !hasLoadedCareerElo;
        errorMessage = null;
      });
    }
    final result = await widget.apiClient.getElo();
    if (!mounted) return;
    setState(() {
      loading = false;
      networkAvailable = result.status.networkError == null;
      if (result.isSuccess && result.data != null) {
        final nextElo = result.data!.elo;
        if (hasLoadedCareerElo && nextElo != careerElo) {
          ratingDelta = CareerRatingDelta(before: careerElo, after: nextElo);
          ratingDeltaToken += 1;
          ratingDeltaTimer?.cancel();
          ratingDeltaTimer = Timer(const Duration(milliseconds: 1800), () {
            if (!mounted) return;
            setState(() => ratingDelta = null);
          });
        }
        careerElo = nextElo;
        hasLoadedCareerElo = true;
      } else {
        hasLoadedCareerElo = true;
        errorMessage = result.status.errorMessage ??
            'Career progress is not available right now.';
      }
    });
    if (widget.rematchRequest > 0 && !rematchStarted && errorMessage == null) {
      rematchStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startCareerMatch());
      });
    }
  }

  @override
  void dispose() {
    ratingDeltaTimer?.cancel();
    super.dispose();
  }

  Future<void> _startCareerMatch() async {
    if (loading) return;
    if (widget.apiClient.session == null) {
      showAppFeedback(
        context,
        'Sign in before starting Career Mode.',
        tone: AppFeedbackTone.warning,
      );
      widget.onNavigate('Auth');
      return;
    }
    final progress = CareerModeProgress.fromElo(careerElo);
    final opponent = _careerOpponentForMatch(progress);
    final accepted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.66),
      barrierDismissible: false,
      builder: (dialogContext) => _CareerMatchDialog(
        progress: progress,
        opponent: opponent,
        allowMaia3: networkAvailable,
      ),
    );
    if (!mounted || accepted != true) return;
    widget.onLaunchCareerGame(opponent.toBotGameConfig(progress: progress));
  }

  CareerOpponentProfile _careerOpponentForMatch(CareerModeProgress progress) {
    final excluded = widget.excludedOpponentName.trim().toLowerCase();
    final seed = DateTime.now().millisecondsSinceEpoch;
    for (var offset = 0; offset < 12; offset += 1) {
      final opponent = CareerOpponentProfile.matchFor(
        progress: progress,
        seed: seed + offset,
        allowMaia3: networkAvailable,
      );
      if (excluded.isEmpty || opponent.name.toLowerCase() != excluded) {
        return opponent;
      }
    }
    return CareerOpponentProfile.matchFor(
      progress: progress,
      seed: seed,
      allowMaia3: networkAvailable,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final androidPhoneLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        viewport.width > viewport.height &&
        viewport.width < 1000 &&
        viewport.height < 600;
    final windowsLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        viewport.width > viewport.height;
    final progress = CareerModeProgress.fromElo(careerElo);
    final nextOpponent = CareerOpponentProfile.matchFor(
      progress: progress,
      seed: 1,
      allowMaia3: networkAvailable,
    );
    return ResponsivePage(
      compactLandscapeOverride: androidPhoneLandscape,
      disableCompactLandscape: windowsLandscape,
      children: (context, spec) {
        final compactLandscape = spec.compactLandscape;
        final dashboardLayout = compactLandscape || windowsLandscape;
        final clockCompact = compactLandscape && widget.isChessnutClockDevice;
        final clockLargeText =
            clockCompact && MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final contentHeight = spec.heightAfterHeader(
          min: dashboardLayout ? 0 : 360,
        );
        final hero = _CareerHeroCard(
          loading: loading,
          progress: progress,
          ratingDelta: ratingDelta,
          ratingDeltaToken: ratingDeltaToken,
          errorMessage: errorMessage,
          onStart: _startCareerMatch,
          onSignIn: () => widget.onNavigate('Auth'),
          compact: dashboardLayout,
          phoneCompact: androidPhoneLandscape,
          clockTight: clockLargeText,
        );
        final journey = _CareerPathCard(
          progress: progress,
          onNavigate: widget.onNavigate,
          compact: dashboardLayout,
          phoneCompact: androidPhoneLandscape,
          showTrainingRecommendations: !dashboardLayout,
          clockTight: clockLargeText,
        );
        final boss = _UpcomingBossCard(
          progress: progress,
          opponent: nextOpponent,
          compact: dashboardLayout,
          phoneCompact: androidPhoneLandscape,
          clockTight: clockLargeText,
        );
        final compactDashboard = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: SectionColumn(
                spacing: clockLargeText ? 4 : spec.gutter,
                children: [
                  if (clockLargeText) hero else Expanded(child: hero),
                  boss,
                ],
              ),
            ),
            SizedBox(width: spec.gutter),
            Expanded(
              flex: 7,
              child: widget.isChessnutClockDevice
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: double.infinity,
                        child: journey,
                      ),
                    )
                  : journey,
            ),
          ],
        );
        final trainingRecommendations = _CareerTrainingRecommendations(
          progress: progress,
          onNavigate: widget.onNavigate,
          compact: true,
          showHeader: false,
          fillAvailableHeight: windowsLandscape,
          adaptToTextScale: widget.isChessnutClockDevice,
          clockTight: clockLargeText,
        );
        final compactTraining = SizedBox(
          height: androidPhoneLandscape
              ? 52
              : windowsLandscape
                  ? (spec.height * 0.14).clamp(82.0, 140.0).toDouble()
                  : 64,
          child: trainingRecommendations,
        );

        final header = ScreenHeader(
          title: 'Career',
          subtitle: 'ELO journey',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: IconButton.filledTonal(
            onPressed: _loadCareer,
            icon: const Icon(Icons.refresh_rounded),
          ),
        );
        return [
          header,
          SizedBox(height: spec.gutter),
          if (loading && !hasLoadedCareerElo)
            SizedBox(
              key: const ValueKey('career-initial-loading'),
              height: dashboardLayout
                  ? contentHeight
                  : math.min(360, contentHeight),
              child: GlassPanel(
                child: Center(
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            )
          else if (windowsLandscape)
            SizedBox(
              key: const ValueKey('career-windows-landscape'),
              height: math.min(
                contentHeight,
                (spec.height * 0.70).clamp(400.0, 680.0).toDouble(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: compactDashboard),
                  SizedBox(height: spec.gutter),
                  compactTraining,
                ],
              ),
            )
          else if (androidPhoneLandscape)
            SizedBox(
              key: const ValueKey('career-android-phone-landscape'),
              height: (contentHeight - 8).clamp(0, contentHeight).toDouble(),
              child: SingleChildScrollView(
                key: const ValueKey('career-android-phone-landscape-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: math.max(
                        192,
                        contentHeight - 8 - spec.gutter - 52,
                      ),
                      child: compactDashboard,
                    ),
                    SizedBox(height: spec.gutter),
                    compactTraining,
                  ],
                ),
              ),
            )
          else if (clockCompact)
            Column(
              key: const ValueKey('career-clock-landscape'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (clockLargeText)
                  IntrinsicHeight(child: compactDashboard)
                else
                  SizedBox(
                    height: math.max(
                      192,
                      contentHeight - 8 - spec.gutter - 64,
                    ),
                    child: compactDashboard,
                  ),
                SizedBox(height: spec.gutter),
                trainingRecommendations,
              ],
            )
          else if (compactLandscape)
            SizedBox(
              height: (contentHeight - 8).clamp(0, contentHeight).toDouble(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: compactDashboard),
                  SizedBox(height: spec.gutter),
                  compactTraining,
                ],
              ),
            )
          else
            ResponsiveSplit(
              breakpoint: 900,
              spacing: spec.gutter,
              leadingFlex: 6,
              trailingFlex: 5,
              leading: SectionColumn(
                spacing: 12,
                children: [
                  hero,
                  journey,
                ],
              ),
              trailing: SectionColumn(
                spacing: 12,
                children: [
                  boss,
                ],
              ),
            ),
        ];
      },
    );
  }
}

class _CareerHeroCard extends StatelessWidget {
  const _CareerHeroCard({
    required this.loading,
    required this.progress,
    required this.ratingDelta,
    required this.ratingDeltaToken,
    required this.errorMessage,
    required this.onStart,
    required this.onSignIn,
    this.compact = false,
    this.phoneCompact = false,
    this.clockTight = false,
  });

  final bool loading;
  final CareerModeProgress progress;
  final CareerRatingDelta? ratingDelta;
  final int ratingDeltaToken;
  final String? errorMessage;
  final VoidCallback onStart;
  final VoidCallback onSignIn;
  final bool compact;
  final bool phoneCompact;
  final bool clockTight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    if (compact) {
      return GlassPanel(
        key: const ValueKey('career-hero-card'),
        padding: EdgeInsets.all(clockTight ? 6 : (phoneCompact ? 10 : 12)),
        tint: scheme.primary.withValues(alpha: 0.08),
        child: Center(
          child: Row(
            children: [
              Container(
                width: phoneCompact ? 36 : 42,
                height: phoneCompact ? 36 : 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.military_tech_rounded,
                  color: scheme.primary,
                  size: phoneCompact ? 21 : 24,
                ),
              ),
              SizedBox(width: phoneCompact ? 8 : 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (phoneCompact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              progress.levelLabel,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              loading
                                  ? 'Loading rating'
                                  : 'Career ELO ${progress.currentElo}',
                              maxLines: 1,
                              softWrap: false,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: tokens.success,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        progress.levelLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    if (!phoneCompact) ...[
                      const SizedBox(height: 2),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Text(
                            loading
                                ? 'Loading rating'
                                : 'Career ELO ${progress.currentElo}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: tokens.success,
                                      fontWeight: FontWeight.w900,
                                    ),
                          ),
                          if (ratingDelta != null)
                            Positioned(
                              key: ValueKey(
                                'career-rating-delta-position-$ratingDeltaToken',
                              ),
                              right: 0,
                              top: -24,
                              child: _CareerFloatingDelta(
                                key: ValueKey(
                                  'career-floating-delta-$ratingDeltaToken',
                                ),
                                delta: ratingDelta!,
                              ),
                            ),
                        ],
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          errorMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.warning),
                        ),
                      ],
                    ],
                    SizedBox(height: clockTight ? 3 : (phoneCompact ? 5 : 7)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        key: const ValueKey('career-hero-progress'),
                        minHeight: 7,
                        value: loading ? null : progress.progress,
                        color: scheme.primary,
                        backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: phoneCompact ? 8 : 10),
              SizedBox(
                width: phoneCompact ? 140 : 224,
                child: _CareerLandscapeStartButton(
                  loading: loading,
                  onStart: onStart,
                  phoneCompact: phoneCompact,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GlassPanel(
      key: const ValueKey('career-hero-card'),
      padding: const EdgeInsets.all(16),
      tint: scheme.primary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.military_tech_rounded,
                  color: scheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.levelLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text(
                          loading
                              ? 'Loading career rating'
                              : 'Career ELO ${progress.currentElo}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: tokens.success,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        if (ratingDelta != null)
                          Positioned(
                            key: ValueKey(
                              'career-rating-delta-position-$ratingDeltaToken',
                            ),
                            right: 0,
                            top: -26,
                            child: _CareerFloatingDelta(
                              key: ValueKey(
                                'career-floating-delta-$ratingDeltaToken',
                              ),
                              delta: ratingDelta!,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: const ValueKey('career-hero-progress'),
              minHeight: 10,
              value: loading ? null : progress.progress,
              color: scheme.primary,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: TextStyle(color: tokens.warning),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            key: const ValueKey('career-find-opponent-button'),
            label: loading ? 'Loading' : 'Find career opponent',
            icon: Icons.travel_explore_rounded,
            onPressed: loading ? null : onStart,
            labelMaxLines: 1,
            labelSoftWrap: false,
            labelOverflow: TextOverflow.ellipsis,
            scaleLabel: true,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in / register'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CareerFloatingDelta extends StatelessWidget {
  const _CareerFloatingDelta({required this.delta, super.key});

  final CareerRatingDelta delta;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final color = delta.isGain
        ? tokens.success
        : delta.isLoss
            ? tokens.danger
            : tokens.info;
    final icon = delta.isGain
        ? Icons.arrow_upward_rounded
        : delta.isLoss
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 860),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: (1 - (value * 0.10)).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -10 * value),
            child: child,
          ),
        );
      },
      child: Container(
        key: const ValueKey('career-rating-delta-feedback'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              delta.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerLandscapeStartButton extends StatelessWidget {
  const _CareerLandscapeStartButton({
    required this.loading,
    required this.onStart,
    this.phoneCompact = false,
  });

  final bool loading;
  final VoidCallback onStart;
  final bool phoneCompact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('career-find-opponent-button'),
      onPressed: loading ? null : onStart,
      icon: Icon(
        Icons.travel_explore_rounded,
        size: phoneCompact ? 18 : 20,
      ),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          loading ? 'Loading' : 'Find career opponent',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(phoneCompact ? 36 : 56),
        padding: EdgeInsets.symmetric(
          horizontal: phoneCompact ? 10 : 14,
          vertical: phoneCompact ? 6 : 8,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _CareerPathCard extends StatelessWidget {
  const _CareerPathCard({
    required this.progress,
    required this.onNavigate,
    this.compact = false,
    this.phoneCompact = false,
    this.showTrainingRecommendations = true,
    this.clockTight = false,
  });

  final CareerModeProgress progress;
  final ValueChanged<String> onNavigate;
  final bool compact;
  final bool phoneCompact;
  final bool showTrainingRecommendations;
  final bool clockTight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eloLeft = math.max(0, progress.nextElo - progress.currentElo);
    final readyForBoss = eloLeft == 0;
    return GlassPanel(
      padding: EdgeInsets.all(
        clockTight ? 6 : (phoneCompact ? 8 : (compact ? 12 : 16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: phoneCompact
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Career Journey',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 16 : 18,
                          ),
                        ),
                      )
                    : Text(
                        'Career Journey',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 16 : 18,
                        ),
                      ),
              ),
              _CareerPill(
                icon: Icons.route_rounded,
                label: 'Stage ${progress.level}',
                color: scheme.primary,
                dense: phoneCompact,
              ),
            ],
          ),
          if (readyForBoss) ...[
            SizedBox(height: compact ? 7 : 10),
            _CareerBossReadyBanner(compact: compact),
          ],
          SizedBox(height: phoneCompact ? 4 : (compact ? 7 : 12)),
          _CareerJourneyMap(
            progress: progress,
            compact: compact,
            clockTight: clockTight,
          ),
          if (showTrainingRecommendations) ...[
            SizedBox(height: compact ? 7 : 12),
            _CareerTrainingRecommendations(
              progress: progress,
              onNavigate: onNavigate,
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _CareerBossReadyBanner extends StatelessWidget {
  const _CareerBossReadyBanner({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.94 + value * 0.06,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        key: const ValueKey('career-boss-ready-banner'),
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: tokens.success.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.success.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: tokens.success.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 32 : 36,
              height: compact ? 32 : 36,
              decoration: BoxDecoration(
                color: tokens.success.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bolt_rounded,
                color: tokens.success,
                size: compact ? 18 : 24,
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boss challenge unlocked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 13 : null,
                    ),
                  ),
                  Text(
                    'Win the boss match to enter the next stage.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
                          fontSize: compact ? 11 : null,
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

class _CareerJourneyMap extends StatelessWidget {
  const _CareerJourneyMap({
    required this.progress,
    this.compact = false,
    this.clockTight = false,
  });

  final CareerModeProgress progress;
  final bool compact;
  final bool clockTight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final bossReady = progress.progress >= 1;
    final remaining = math.max(0, progress.nextElo - progress.currentElo);
    return Container(
      key: const ValueKey('career-component-route'),
      padding: EdgeInsets.all(clockTight ? 6 : (compact ? 10 : 14)),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _CareerEloBadge(
                label: 'Now',
                value: '${progress.currentElo}',
                color: tokens.success,
                compact: compact,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _CareerRouteProgressTrack(
                    progress: progress.progress,
                    ready: bossReady,
                  ),
                ),
              ),
              _CareerEloBadge(
                key: const ValueKey('career-route-step-boss'),
                label: bossReady ? 'Boss ready' : 'Boss',
                value: '${progress.nextElo}',
                color: bossReady ? tokens.success : tokens.warning,
                compact: compact,
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 10),
            Text(
              bossReady
                  ? 'Stage ${progress.level} complete. Challenge the boss to enter the next stage.'
                  : 'Gain $remaining more ELO through battles and training to unlock the boss.',
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 7),
            Text(
              bossReady
                  ? 'Stage ${progress.level} complete. Challenge the boss to enter the next stage.'
                  : 'Gain $remaining more ELO through battles and training to unlock the boss.',
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.15,
                  ),
            ),
            const SizedBox(height: 7),
          ],
          _CareerStageFocusRow(
            battleElo: progress.delta,
            bossReady: bossReady,
            compact: compact,
            clockTight: clockTight,
          ),
        ],
      ),
    );
  }
}

class _CareerRouteProgressTrack extends StatelessWidget {
  const _CareerRouteProgressTrack({
    required this.progress,
    required this.ready,
  });

  final double progress;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    return Column(
      key: const ValueKey('career-route-progress-track'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: scheme.primary.withValues(alpha: 0.74),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  color: ready ? tokens.success : scheme.primary,
                  backgroundColor: scheme.primary.withValues(alpha: 0.14),
                ),
              ),
            ),
            Icon(
              ready
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_outline_rounded,
              size: 16,
              color: ready ? tokens.success : tokens.warning,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${(progress * 100).round()}%',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.60),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                height: 1,
              ),
        ),
      ],
    );
  }
}

class _CareerEloBadge extends StatelessWidget {
  const _CareerEloBadge({
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
    super.key,
  });

  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 76 : 72),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.66),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          SizedBox(height: compact ? 3 : 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerStageFocusRow extends StatelessWidget {
  const _CareerStageFocusRow({
    required this.battleElo,
    required this.bossReady,
    this.compact = false,
    this.clockTight = false,
  });

  final int battleElo;
  final bool bossReady;
  final bool compact;
  final bool clockTight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final focusText = bossReady
        ? 'Boss is unlocked. Start a career match to challenge the next stage.'
        : 'Win career games for +$battleElo ELO. Use training below if this stage gets stuck.';
    final focusStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.74),
          fontWeight: FontWeight.w700,
          height: 1.15,
        );
    return Container(
      key: const ValueKey('career-stage-focus-row'),
      padding: EdgeInsets.all(clockTight ? 4 : (compact ? 7 : 12)),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 30 : 38,
            height: compact ? 30 : 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              bossReady ? Icons.emoji_events_rounded : Icons.bolt_rounded,
              color: bossReady ? tokens.success : scheme.primary,
              size: compact ? 18 : 21,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: compact
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      focusText,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: focusStyle,
                    ),
                  )
                : Text(
                    focusText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: focusStyle,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CareerTrainingRecommendations extends StatelessWidget {
  const _CareerTrainingRecommendations({
    required this.progress,
    required this.onNavigate,
    this.compact = false,
    this.showHeader = true,
    this.fillAvailableHeight = false,
    this.adaptToTextScale = false,
    this.clockTight = false,
  });

  final CareerModeProgress progress;
  final ValueChanged<String> onNavigate;
  final bool compact;
  final bool showHeader;
  final bool fillAvailableHeight;
  final bool adaptToTextScale;
  final bool clockTight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final recommendations = [
      _CareerTrainingAction(
        number: '1',
        icon: Icons.extension_rounded,
        title: 'Puzzle Practice',
        detail: 'Train tactics linked to recent mistakes',
        route: 'PuzzleThemes',
        color: tokens.warning,
      ),
      _CareerTrainingAction(
        number: '2',
        icon: Icons.analytics_rounded,
        title: 'Review Last Loss',
        detail: 'Review the game that blocked this node',
        route: 'Records',
        color: tokens.info,
      ),
      _CareerTrainingAction(
        number: '3',
        icon: Icons.menu_book_rounded,
        title: 'Mistake book',
        detail: 'From your games',
        route: 'MistakeBook',
        color: scheme.primary,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Row(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Training recommendations',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 15 : 16,
                  ),
                ),
              ),
              _CareerTrainingStatusPill(compact: compact),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              'If this stage keeps blocking you, train one weakness and come back for the challenge.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          SizedBox(height: compact ? 2 : 8),
        ],
        if (compact)
          if (fillAvailableHeight)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < recommendations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _CareerTrainingCard(
                        action: recommendations[i],
                        onTap: () => onNavigate(recommendations[i].route),
                        compact: true,
                        centerContentVertically: true,
                        adaptToTextScale: adaptToTextScale,
                        clockTight: clockTight,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else if (adaptToTextScale)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < recommendations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _CareerTrainingCard(
                        action: recommendations[i],
                        onTap: () => onNavigate(recommendations[i].route),
                        compact: true,
                        centerContentVertically: true,
                        adaptToTextScale: true,
                        clockTight: clockTight,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Row(
              children: [
                for (var i = 0; i < recommendations.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _CareerTrainingCard(
                      action: recommendations[i],
                      onTap: () => onNavigate(recommendations[i].route),
                      compact: true,
                      adaptToTextScale: adaptToTextScale,
                      clockTight: clockTight,
                    ),
                  ),
                ],
              ],
            )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 460;
              const spacing = 10.0;
              final cardWidth = twoColumns
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final item in recommendations)
                    SizedBox(
                      width: cardWidth,
                      child: _CareerTrainingCard(
                        action: item,
                        onTap: () => onNavigate(item.route),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _CareerTrainingAction {
  const _CareerTrainingAction({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
    required this.route,
    required this.color,
  });

  final String number;
  final IconData icon;
  final String title;
  final String detail;
  final String route;
  final Color color;
}

class _CareerTrainingStatusPill extends StatelessWidget {
  const _CareerTrainingStatusPill({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _CareerPill(
      icon: Icons.flag_rounded,
      label: 'If stuck',
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

class _CareerTrainingCard extends StatelessWidget {
  const _CareerTrainingCard({
    required this.action,
    required this.onTap,
    this.compact = false,
    this.centerContentVertically = false,
    this.adaptToTextScale = false,
    this.clockTight = false,
  });

  final _CareerTrainingAction action;
  final VoidCallback onTap;
  final bool compact;
  final bool centerContentVertically;
  final bool adaptToTextScale;
  final bool clockTight;

  @override
  Widget build(BuildContext context) {
    final color = action.color;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(compact ? 10 : 16);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          key: ValueKey('career-training-card-${action.route}'),
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 5)
              : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: compact ? 0.18 : 0.08),
            borderRadius: radius,
            border: Border.all(
              color: color.withValues(alpha: compact ? 0.42 : 0.20),
              width: compact ? 1.2 : 1,
            ),
          ),
          child: compact
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          action.number,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(action.icon, color: color, size: 14),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        mainAxisSize: centerContentVertically
                            ? MainAxisSize.min
                            : MainAxisSize.max,
                        mainAxisAlignment: centerContentVertically
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (adaptToTextScale)
                            Text(
                              action.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            )
                          else
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                action.title,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          const SizedBox(height: 1),
                          if (adaptToTextScale)
                            Text(
                              action.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                action.detail,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(action.icon, color: color, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            action.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.70),
                                  height: 1.15,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: color, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

class _UpcomingBossCard extends StatelessWidget {
  const _UpcomingBossCard({
    required this.progress,
    required this.opponent,
    this.compact = false,
    this.phoneCompact = false,
    this.clockTight = false,
  });

  final CareerModeProgress progress;
  final CareerOpponentProfile opponent;
  final bool compact;
  final bool phoneCompact;
  final bool clockTight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final engineIcon = switch (opponent.engineKind) {
      BotEngineKind.stockfish => Icons.memory_rounded,
      BotEngineKind.maia3 => Icons.cloud_rounded,
      _ => Icons.psychology_rounded,
    };
    final engineLabel = switch (opponent.engineKind) {
      BotEngineKind.stockfish => 'Stockfish',
      BotEngineKind.maia3 => 'Maia 3',
      _ => 'Maia',
    };
    final enginePill = _CareerPill(
      icon: engineIcon,
      label: engineLabel,
      color: scheme.primary,
      dense: phoneCompact,
    );
    final openingPill = _CareerPill(
      icon: Icons.account_tree_rounded,
      label: opponent.opening.name,
      color: scheme.secondary,
      dense: phoneCompact,
    );
    return GlassPanel(
      padding: EdgeInsets.all(clockTight ? 6 : (compact ? 10 : 14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upcoming Opponent',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: phoneCompact ? 14 : (compact ? 15 : 18),
            ),
          ),
          SizedBox(
            height: clockTight ? 2 : (phoneCompact ? 4 : (compact ? 8 : 12)),
          ),
          Row(
            children: [
              _CareerAvatar(
                asset: opponent.avatarAsset,
                size:
                    clockTight ? 34 : (phoneCompact ? 40 : (compact ? 46 : 64)),
              ),
              SizedBox(width: phoneCompact ? 7 : (compact ? 9 : 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: phoneCompact ? 14 : (compact ? 15 : 17),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${opponent.style} / ELO ${opponent.elo}',
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: compact
                          ? Theme.of(context).textTheme.bodySmall
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: clockTight ? 2 : (phoneCompact ? 4 : (compact ? 8 : 12)),
          ),
          if (phoneCompact)
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: enginePill,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: openingPill,
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: [enginePill, openingPill],
            ),
        ],
      ),
    );
  }
}

class _CareerPill extends StatelessWidget {
  const _CareerPill({
    required this.icon,
    required this.label,
    required this.color,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 16, color: color),
          SizedBox(width: dense ? 4 : 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CareerMatchDialog extends StatefulWidget {
  const _CareerMatchDialog({
    required this.progress,
    required this.opponent,
    required this.allowMaia3,
  });

  final CareerModeProgress progress;
  final CareerOpponentProfile opponent;
  final bool allowMaia3;

  @override
  State<_CareerMatchDialog> createState() => _CareerMatchDialogState();
}

class _CareerMatchDialogState extends State<_CareerMatchDialog> {
  bool matched = false;
  int previewIndex = 0;
  Timer? previewTimer;
  late final List<CareerOpponentProfile> previews;

  @override
  void initState() {
    super.initState();
    previews = List<CareerOpponentProfile>.generate(
      5,
      (index) => CareerOpponentProfile.matchFor(
        progress: widget.progress,
        seed: DateTime.now().millisecondsSinceEpoch + index * 17,
        allowMaia3: widget.allowMaia3,
      ),
    );
    previewTimer = Timer.periodic(const Duration(milliseconds: 240), (_) {
      if (!mounted || matched) return;
      setState(() => previewIndex = (previewIndex + 1) % previews.length);
    });
    Future<void>.delayed(const Duration(milliseconds: 1650), () {
      if (!mounted) return;
      previewTimer?.cancel();
      setState(() => matched = true);
    });
  }

  @override
  void dispose() {
    previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleOpponent = matched ? widget.opponent : previews[previewIndex];
    final engineLabel = switch (visibleOpponent.engineKind) {
      BotEngineKind.stockfish => 'Stockfish',
      BotEngineKind.maia3 => 'Maia 3',
      _ => 'Maia',
    };
    return AppDialogShell(
      icon: matched ? Icons.person_search_rounded : Icons.radar_rounded,
      title: matched ? 'Opponent found' : 'Matching opponent',
      subtitle: matched
          ? '${widget.opponent.name} is ready for a career challenge.'
          : 'Finding a virtual player near ELO ${widget.progress.currentElo}.',
      actions: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 152,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: matched ? 1 : 0.72),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Container(
                          width: 128 + value * 20,
                          height: 128 + value * 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.primary.withValues(
                                alpha: matched ? 0.28 : 0.12 + value * 0.18,
                              ),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: matched
                          ? _CareerAvatar(
                              key: ValueKey(widget.opponent.avatarAsset),
                              asset: widget.opponent.avatarAsset,
                              size: 92,
                            )
                          : _CareerAvatar(
                              key: ValueKey(visibleOpponent.avatarAsset),
                              asset: visibleOpponent.avatarAsset,
                              size: 86,
                            ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey(
                    '${visibleOpponent.name}-${visibleOpponent.elo}-$matched',
                  ),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      visibleOpponent.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: matched ? 22 : 19,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${visibleOpponent.style} / $engineLabel / ELO ${visibleOpponent.elo}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (matched) ...[
                const SizedBox(height: 14),
              ] else ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  minHeight: 5,
                  backgroundColor: scheme.primary.withValues(alpha: 0.10),
                  color: scheme.primary,
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: matched
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CareerAvatar extends StatelessWidget {
  const _CareerAvatar({
    required this.asset,
    required this.size,
    super.key,
  });

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
      ),
      child: ClipOval(
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    );
  }
}
