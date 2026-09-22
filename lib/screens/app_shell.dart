import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/app_preferences_store.dart';
import '../services/app_shared_preferences.dart';
import '../services/account_switcher_store.dart';
import '../services/analysis_report_cache_service.dart';
import '../services/android_app_lifecycle_service.dart';
import '../services/android_home_widget_service.dart';
import '../services/app_update_service.dart';
import '../services/board_background_connection_service.dart';
import '../services/board_storage_import_service.dart';
import '../services/board_settings_service.dart';
import '../services/chess_clock_switch_service.dart';
import '../services/chess_com_pgn_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/chessnut_endpoint_config.dart';
import '../services/course_lesson_service.dart';
import '../services/course_progress_service.dart';
import '../services/daily_claim_service.dart' hide DailyClaimResult;
import '../services/device_performance_service.dart';
import '../services/evo2_usb_board_transport.dart';
import '../services/evo2_usb_power_service.dart';
import '../services/evo2_display_service.dart';
import '../services/game_record_filter.dart';
import '../services/game_record_repository.dart';
import '../services/game_record_save_service.dart';
import '../services/local_game_record_store.dart';
import '../services/lichess_pgn_service.dart';
import '../services/lichess_board_service.dart';
import '../services/login_credential_store.dart';
import '../services/lc0_weight_library_service.dart';
import '../services/mistake_book_service.dart';
import '../services/module_guide_service.dart';
import '../services/network_latency_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_protocol.dart';
import '../services/play_in_app_update_service.dart';
import '../services/recaptcha_service.dart';
import '../services/report_share_service.dart';
import '../services/review_prompt_service.dart';
import '../services/screen_wake_lock_service.dart';
import '../services/session_store.dart';
import '../services/app_sound_service.dart';
import '../services/stockfish_analysis_service.dart';
import '../services/game_notation_service.dart';
import '../services/universal_ble_board_transport.dart';
import '../services/widget_vision_play_service.dart';
import '../services/android_accessibility_vision_service.dart';
import '../services/windows_display_power_service.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/lichess_authorization_dialog.dart';
import '../widgets/turnstile_challenge_dialog.dart';
import 'account_screen.dart';
import 'account_switcher_screen.dart';
import 'analysis_screen.dart';
import 'board_connection_screen.dart';
import 'chess_com_webview_screen.dart';
import 'auth_screen.dart';
import 'board_analyzer_screen.dart';
import 'board_editor_screen.dart';
import 'board_settings_screen.dart';
import 'career_screen.dart';
import 'board_diagnostics_screen.dart';
import 'daily_tasks_screen.dart';
import 'engine_lab_screen.dart';
import 'course_screen.dart';
import 'game_record_screen.dart';
import 'game_room_screen.dart';
import 'home_screen.dart';
import 'chess_clock_screen.dart';
import 'otb_setup_screen.dart';
import 'points_screen.dart';
import 'puzzle_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';
import 'spectator_screen.dart';
import 'splash_screen.dart';
import 'training_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.visualTheme,
    required this.onVisualThemeChanged,
    required this.pageAnimations,
    required this.onPageAnimationsChanged,
    required this.hidePageAnimationsSetting,
    required this.isChessnutClockDevice,
    this.isChessnutEvo2Device = false,
    this.evo2ScreenOrientation = Evo2ScreenOrientation.rotation0,
    this.onEvo2ScreenOrientationChanged,
    required this.boardCoordinatesEnabled,
    required this.onBoardCoordinatesChanged,
    required this.keepBoardConnectedInBackground,
    required this.onKeepBoardConnectedInBackgroundChanged,
    required this.soundEffectsEnabled,
    required this.onSoundEffectsChanged,
    required this.moveAnnouncementEnabled,
    required this.onMoveAnnouncementChanged,
    this.soundEffects = const SoundEffectsSettings(),
    this.onSoundEffectsSettingsChanged,
    required this.languagePreference,
    required this.onLanguagePreferenceChanged,
    required this.apiLanguage,
    this.httpClient,
    this.recaptchaService,
    this.positionAnalyzer,
    this.boardGateway,
    this.authService,
    this.sessionStore,
    this.credentialStore,
    this.appPreferencesStore,
    this.localGameRecordStore,
    this.androidHomeWidgetService = const AndroidHomeWidgetService(),
    this.boardBackgroundConnectionService =
        const MethodChannelBoardBackgroundConnectionService(),
    this.evo2UsbPowerService = const MethodChannelEvo2UsbPowerService(),
    this.clockSwitchService,
    this.networkLatencyProbe,
    this.reviewPromptService,
    this.reportShareService,
    this.courseLessonRepository,
    this.courseProgressStore,
    this.courseVideoAdapterFactory,
    this.analysisPgnFileLoader,
    this.modelBuildPgnFileLoader,
    this.modelBuildFileImportAvailableOverride,
    this.lc0WeightLibraryStore,
    this.initialScreen,
    this.appSoundService = const SystemAppSoundService(),
    this.screenWakeLockService = const SystemScreenWakeLockService(),
    this.windowsDisplayPowerService =
        const MethodChannelWindowsDisplayPowerService(),
    this.turnstileChallengePresenter = showTurnstileChallenge,
    this.lichessAuthorizationPresenter = showLichessAuthorization,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ChessnutVisualTheme visualTheme;
  final ValueChanged<ChessnutVisualTheme> onVisualThemeChanged;
  final bool pageAnimations;
  final ValueChanged<bool> onPageAnimationsChanged;
  final bool hidePageAnimationsSetting;
  final bool isChessnutClockDevice;
  final bool isChessnutEvo2Device;
  final Evo2ScreenOrientation evo2ScreenOrientation;
  final ValueChanged<Evo2ScreenOrientation>? onEvo2ScreenOrientationChanged;
  final bool boardCoordinatesEnabled;
  final ValueChanged<bool> onBoardCoordinatesChanged;
  final bool keepBoardConnectedInBackground;
  final ValueChanged<bool> onKeepBoardConnectedInBackgroundChanged;
  final bool soundEffectsEnabled;
  final ValueChanged<bool> onSoundEffectsChanged;
  final bool moveAnnouncementEnabled;
  final ValueChanged<bool> onMoveAnnouncementChanged;
  final SoundEffectsSettings soundEffects;
  final ValueChanged<SoundEffectsSettings>? onSoundEffectsSettingsChanged;
  final AppLanguagePreference languagePreference;
  final ValueChanged<AppLanguagePreference> onLanguagePreferenceChanged;
  final String apiLanguage;
  final http.Client? httpClient;
  final RecaptchaService? recaptchaService;
  final PositionAnalyzer? positionAnalyzer;
  final PhysicalBoardGateway? boardGateway;
  final AuthService? authService;
  final ChessnutSessionStore? sessionStore;
  final LoginCredentialStore? credentialStore;
  final AppPreferencesStore? appPreferencesStore;
  final LocalGameRecordStore? localGameRecordStore;
  final AndroidHomeWidgetService androidHomeWidgetService;
  final BoardBackgroundConnectionService boardBackgroundConnectionService;
  final Evo2UsbPowerService evo2UsbPowerService;
  final ChessClockSwitchService? clockSwitchService;
  final NetworkLatencyProbe? networkLatencyProbe;
  final ReviewPromptService? reviewPromptService;
  final ReportShareService? reportShareService;
  final CourseLessonRepository? courseLessonRepository;
  final CourseProgressStore? courseProgressStore;
  final CourseVideoAdapter Function()? courseVideoAdapterFactory;
  final AnalysisPgnFileLoader? analysisPgnFileLoader;
  final ModelBuildPgnFileLoader? modelBuildPgnFileLoader;
  final bool? modelBuildFileImportAvailableOverride;
  final Lc0WeightLibraryStore? lc0WeightLibraryStore;
  final String? initialScreen;
  final AppSoundService appSoundService;
  final ScreenWakeLockService screenWakeLockService;
  final WindowsDisplayPowerService windowsDisplayPowerService;
  final TurnstileChallengePresenter turnstileChallengePresenter;
  final LichessAuthorizationPresenter lichessAuthorizationPresenter;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const _hardwareDiagnosticsEnabled = bool.fromEnvironment(
    'CHESSNUT_ENABLE_HARDWARE_DIAGNOSTICS',
  );
  static const double _iosBackSwipeEdgeWidth = 28;
  static const double _iosBackSwipeCommitDistance = 72;
  static const double _iosBackSwipeFlingVelocity = 450;

  int index = 0;
  final List<String> _routeStack = ['Splash'];
  GameLaunchMode gameMode = GameLaunchMode.lichess;
  BotGameConfig botGameConfig = const BotGameConfig.defaultConfig();
  OtbGameConfig otbGameConfig = const OtbGameConfig();
  LichessGameConfig lichessGameConfig = const LichessGameConfig.empty();
  Uri? chessComResumeUrl;
  final DailyClaimService dailyClaimService = DailyClaimService(
    store: InMemoryDailyClaimStore(),
  );
  String? analysisPgn;
  String? analysisReportCacheKey;
  String analysisReviewBackTarget = 'Analysis';
  int? analysisInitialPly;
  int analysisCommentId = 0;
  bool signedIn = false;
  bool boardConnected = false;
  ChessnutBoardModel connectedBoardModel = ChessnutBoardModel.move;
  List<GameRecord> gameRecords = const [];
  List<LocalGameRecord> _localGameRecords = const [];
  LocalGameRecord? _activeLocalGameRecord;
  int? _offlineRecordUserId;
  int _localRecordLoadGeneration = 0;
  late final LocalGameRecordStore localGameRecordStore;
  late final GameRecordSaveService gameRecordSaveService;
  int? get _localRecordUserId =>
      apiClient.session?.userId ?? _offlineRecordUserId;
  List<GameRecord> _liveLichessContinueRecords = const [];
  GameRecord? _localContinueBotRecord;
  bool _returnHomeAfterPostGameBotSettings = false;
  int? activeGameRecordId;
  String? activeGameShareId;
  SpectatorGameSnapshot activeSpectatorSnapshot =
      const SpectatorGameSnapshot.empty();
  ChessnutHomeWidgetLaunchAction? _pendingHomeWidgetAction;
  late final ChessnutApiClient apiClient;
  late final AppUpdateService appUpdateService;
  late final GameRecordRepository gameRecordRepository;
  late PhysicalBoardGateway boardGateway;
  PhysicalBoardGateway? usbBoardGateway;
  late final bool ownsBoardGateway;
  bool ownsUsbBoardGateway = false;
  late final ChessnutSessionStore sessionStore;
  late final LoginCredentialStore credentialStore;
  late final AccountSwitcherStore accountSwitcherStore;
  late final ReviewPromptService reviewPromptService;
  late final ChessClockSwitchService clockSwitchService;
  late final AppPreferencesStore appPreferencesStore;
  late final AppPreferencesAnalysisReportCacheStore analysisReportCacheStore;
  late final AppPreferencesMistakeBookStore mistakeBookStore;
  late final Lc0WeightLibraryStore lc0WeightLibraryStore;
  BoardSettingsState boardSettings = const BoardSettingsState();
  bool widgetVisionEnabled = false;
  int _visionStateGeneration = 0;
  bool visionRecognitionOnly = false;
  bool _homeWidgetActionInFlight = false;
  StreamSubscription<PhysicalBoardConnectionState>? _shellBoardStateSub;
  StreamSubscription<BoardBatteryStatus>? _shellBoardBatterySub;
  StreamSubscription<String>? _shellBoardFenSub;
  StreamSubscription<bool>? _windowsDisplayPowerSub;
  Timer? _shellBoardBatteryTimer;
  String? _lastKeepAliveBoardFen;
  Evo2ScreenOffGameController? _evo2ScreenOffGameController;
  int _evo2LedRefreshRequestId = 0;
  int _screenWakeFenActivityId = 0;
  bool _reportedScreenOffGameActive = false;
  String? _lastScreenOffGameRouteLabel;
  Timer? _backgroundHomeWidgetPollTimer;
  late final WidgetVisionPlayService widgetVisionPlayService;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  bool _windowsDisplayOff = false;
  BoardBatteryStatus? boardBatteryStatus;
  PhysicalBoardGateway? _ledSettingsBoardGatewayCache;
  PhysicalBoardGateway? _playBoardGatewayCache;
  PhysicalBoardGateway? _ledSettingsBoardGatewayDelegate;
  PhysicalBoardGateway? _playBoardGatewayDelegate;

  PhysicalBoardGateway get _ledSettingsBoardGateway {
    if (!identical(_ledSettingsBoardGatewayDelegate, boardGateway)) {
      _ledSettingsBoardGatewayDelegate = boardGateway;
      _ledSettingsBoardGatewayCache = _BoardLedSettingsGateway(
        boardGateway,
        ledEnabled: () => boardSettings.piecePositionLed,
        boardInteractionEnabled: () => _screenOffBoardInteractionEnabled,
      );
    }
    return _ledSettingsBoardGatewayCache!;
  }

  PhysicalBoardGateway get _playBoardGateway {
    if (!identical(_playBoardGatewayDelegate, boardGateway)) {
      _playBoardGatewayDelegate = boardGateway;
      _playBoardGatewayCache = _BoardLedSettingsGateway(
        boardGateway,
        ledEnabled: () =>
            boardSettings.piecePositionLed &&
            (gameMode != GameLaunchMode.lichess || lichessGameConfig.moveLeds),
        boardInteractionEnabled: () => _screenOffBoardInteractionEnabled,
      );
    }
    return _playBoardGatewayCache!;
  }

  bool _boardReconnectInFlight = false;
  bool _boardReconnectAttemptedForDisconnect = false;
  bool _builtInBoardAutoConnectInFlight = false;
  bool _iosBackSwipeTriggered = false;
  double _iosBackSwipeDistance = 0;
  bool _appUpdateCheckInFlight = false;
  bool _startupAppUpdateChecked = false;
  bool _appUpdateDismissedForProcess = false;
  AppUpdateReminderState _appUpdateReminder = const AppUpdateReminderState();
  Future<void>? _appUpdateReminderLoadFuture;
  final PlayInAppUpdateService playInAppUpdateService =
      const PlayInAppUpdateService();
  static const int _gameRecordPageSize = 10;
  bool recordsLoading = false;
  bool recordsLoadingMore = false;
  bool _recordsAutoRefreshInFlight = false;
  bool recordsReloadQueued = false;
  int _gameRecordsPage = 0;
  bool _gameRecordsHasMore = false;
  int _gameRecordsTotal = 0;
  int _gameRecordsTotalPage = 1;
  Map<RecordSourceTab, int>? _gameRecordSourceCounts;
  Future<void>? _recordsLoadFuture;
  int _recordsRefreshGeneration = 0;
  String? recordsError;
  bool _ongoingLichessGamesRefreshInFlight = false;
  final Set<int> _deletedGameRecordIds = {};
  final Set<String> _dismissedContinueRecordKeys = {};
  final Set<int> _knownCompletedPersonalEngineIds = {};
  final Set<int> _unseenCompletedPersonalEngineIds = {};
  bool _engineCompletionBaselineInitialized = false;
  Set<String> _seenModuleGuideIds = const {};
  bool _moduleGuidePreferencesLoaded = false;
  bool _initialGuideAutoPromptCompleted = false;
  String? _activeModuleGuideId;
  bool _moduleGuideReplayInProgress = false;
  String? _suppressedAutoGuideRouteLabel;
  final Set<String> _dailyTaskRewardClaimsInFlight = {};
  final Set<String> _dailyTaskRewardClaimsDone = {};
  bool _walletTaskRefreshInFlight = false;
  WalletBalance? _walletBalanceSnapshot;

  bool get _usesWindowsGuideLayout =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool get _usesSafeAreaAdjustedGuideLayout =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _supportsAccountSwitcher =>
      !kIsWeb && supportsAccountSwitcherPlatform(defaultTargetPlatform);
  bool? _dailyCheckInClaimed;
  int _dailyClaimPoints = dailyCheckInRewardPoints;
  final Set<String> _claimedDailyTaskKeys = {};
  Map<String, GameAnalysisReportStatus> analysisReportStatuses = const {};
  int _mistakeBookRefreshToken = 0;
  String boardEditorFen = chessnutStandardStartFen;
  String boardAnalyzerInitialFen = chessnutStandardStartFen;
  int boardEditorBotRequestId = 0;
  int _careerRematchRequest = 0;
  String _careerRematchExcludedOpponent = '';

  static const _reviewPromptAppVersion =
      String.fromEnvironment('CHESSNUT_APP_VERSION', defaultValue: '0.1.0');

  late final List<AppRouteItem> routes = [
    AppRouteItem(
        label: 'Splash',
        icon: Icons.motion_photos_on_rounded,
        builder: (_) => SplashScreen(onComplete: _completeSplash)),
    AppRouteItem(
        label: 'Auth',
        icon: Icons.login_rounded,
        builder: (context) => AuthScreen(
              onNavigate: _go,
              onContinueAsGuest: _continueAsGuest,
              apiClient: apiClient,
              recaptchaService: widget.recaptchaService,
              turnstileChallengePresenter: widget.turnstileChallengePresenter,
              authService: widget.authService,
              sessionStore: sessionStore,
              credentialStore: credentialStore,
              onSignedIn: (session) => _completeSignIn(
                session,
                renewAccountValidity: true,
              ),
              compactLandscapeOverride: widget.isChessnutEvo2Device &&
                  MediaQuery.sizeOf(context).width >
                      MediaQuery.sizeOf(context).height,
            )),
    AppRouteItem(
        label: 'Home',
        icon: Icons.home_rounded,
        builder: (_) => HomeScreen(
              onNavigate: _go,
              boardConnected: boardConnected,
              boardModel: connectedBoardModel,
              dailyClaimService: dailyClaimService,
              apiClient: apiClient,
              engineBuildCompletedBubble:
                  _unseenCompletedPersonalEngineIds.isNotEmpty,
              walletBalanceSnapshot: _walletBalanceSnapshot,
              dailyCheckInClaimed: _dailyCheckInClaimed,
              claimedDailyTaskKeys: Set<String>.unmodifiable(
                _claimedDailyTaskKeys,
              ),
              onWalletBalanceLoaded: _updateDailyTaskStateFromWallet,
              continueRecord: _activeContinueRecord,
              continueBotRecord: _activeContinueBotRecord,
              continueOnlineRecord: _activeContinueOnlineRecord,
              continueOnlineRecords: _activeContinueOnlineRecords,
              continueLocalRecords: _activeContinueLocalRecords,
              onContinueRecord: _continueRecord,
              onDismissContinueRecord: _dismissContinueRecord,
              visionEnabled: widgetVisionEnabled,
              onVisionEnabledChanged: _setHomeWidgetVisionEnabled,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              isChessnutEvo2Device: widget.isChessnutEvo2Device,
            )),
    AppRouteItem(
        label: 'ConnectBoard',
        icon: Icons.bluetooth_searching_rounded,
        builder: (_) => BoardConnectionScreen(
              onNavigate: _go,
              onConnected: _connectBoard,
              gateway: boardGateway,
              usbGateway: widget.isChessnutClockDevice ? null : usbBoardGateway,
              usbGatewayFactory: widget.isChessnutClockDevice
                  ? null
                  : () {
                      usbBoardGateway ??= EasyLinkBoardGateway();
                      ownsUsbBoardGateway = true;
                      return usbBoardGateway!;
                    },
              enableUsbConnection: !widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'DailyTasks',
        icon: Icons.task_alt_rounded,
        builder: (_) => DailyTasksScreen(
              onNavigate: _go,
              dailyClaimService: dailyClaimService,
              apiClient: apiClient,
              walletBalanceSnapshot: _walletBalanceSnapshot,
              claimedDailyTaskKeys: Set<String>.unmodifiable(
                _claimedDailyTaskKeys,
              ),
              onDailyTaskStateChanged: _updateDailyTaskState,
            )),
    if (_hardwareDiagnosticsEnabled)
      AppRouteItem(
          label: 'HardwareTest',
          icon: Icons.bug_report_rounded,
          builder: (_) => BoardDiagnosticsScreen(onNavigate: _go)),
    AppRouteItem(
        label: 'Play',
        icon: Icons.play_arrow_rounded,
        builder: (_) => GameRoomScreen(
              onNavigate: _go,
              mode: gameMode,
              botConfig: botGameConfig,
              otbConfig: otbGameConfig,
              lichessConfig: lichessGameConfig,
              apiClient: apiClient,
              recordSaveService: gameRecordSaveService,
              initialLocalRecord: _activeLocalGameRecord,
              recordOwnerUserId: _localRecordUserId,
              boardGateway: _playBoardGateway,
              boardSettings: boardSettings,
              onBoardSettingsChanged: _updateBoardSettings,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              soundEffectsEnabled: widget.soundEffectsEnabled,
              soundEffects: widget.soundEffects,
              appSoundService: widget.appSoundService,
              latencyProbe: widget.networkLatencyProbe,
              positionAnalyzer: widget.positionAnalyzer,
              onAnalyzePgn: (pgn) => _openPostGameAnalysis(pgn: pgn),
              reviewPromptService: reviewPromptService,
              onGameCompleted: (completion) {
                final careerReward = completion.careerDailyTaskReward;
                if (careerReward != null) {
                  _applyDailyTaskReward('career', careerReward);
                }
              },
              onGameActiveChanged: _updateScreenOffGameActive,
              evo2LedRefreshRequestId: _evo2LedRefreshRequestId,
              onGameShared: (snapshot) {
                setState(() => activeSpectatorSnapshot = snapshot);
              },
              onGameRecordSaved: _recordSavedCallback(),
              onCareerRematch: _rematchCareerOpponent,
              onLichessTemporaryContinueRecord: _refreshAfterLeavingLichessGame,
              onBotTemporaryContinueRecord: _storeLocalBotContinueRecord,
              onPostGameBotSettings: () {
                _returnHomeAfterPostGameBotSettings = true;
              },
              initialPgnId: activeGameRecordId,
              initialShareId: activeGameShareId,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
              clockSwitchService: clockSwitchService,
            )),
    AppRouteItem(
        label: 'Setup',
        icon: Icons.route_rounded,
        builder: (_) => SetupScreen(
              onNavigate: _go,
              onLaunchGame: _launchGame,
              boardGateway: _ledSettingsBoardGateway,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
            )),
    AppRouteItem(
        label: 'OtbSetup',
        icon: Icons.people_alt_rounded,
        builder: (_) => OtbSetupScreen(
              onNavigate: _go,
              onLaunchGame: _launchGame,
              boardGateway: _ledSettingsBoardGateway,
              boardSettings: boardSettings,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
            )),
    AppRouteItem(
        label: 'Bot',
        icon: Icons.smart_toy_rounded,
        builder: (_) => BotSetupScreen(
              onNavigate: _go,
              onLaunchGame: _launchGame,
              initialConfig: botGameConfig,
              boardEditorFen: boardEditorFen,
              boardEditorRequestId: boardEditorBotRequestId,
              boardGateway: _ledSettingsBoardGateway,
              boardSettings: boardSettings,
              apiClient: apiClient,
              lc0WeightLibraryStore: lc0WeightLibraryStore,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
            )),
    AppRouteItem(
        label: 'Online',
        icon: Icons.public_rounded,
        builder: (_) => OnlineSetupScreen(
              onNavigate: _go,
              onLaunchGame: _launchGame,
              apiClient: apiClient,
              boardSettings: boardSettings,
              onBoardSettingsChanged: _updateBoardSettings,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              onSessionUpdated: (session) {
                setState(() {
                  apiClient.session = session;
                });
                if (_supportsAccountSwitcher) {
                  unawaited(accountSwitcherStore.upsert(
                    SavedChessnutAccount.fromSession(session),
                  ));
                }
                unawaited(_refreshOngoingLichessGames());
                final refreshToken = session.refreshToken;
                if (refreshToken != null && refreshToken.trim().isNotEmpty) {
                  sessionStore
                      .write(
                        StoredChessnutSession(
                          userId: session.userId,
                          refreshToken: refreshToken,
                        ),
                      )
                      .ignore();
                }
              },
              lichessAuthorizationPresenter:
                  widget.lichessAuthorizationPresenter,
            )),
    AppRouteItem(
        label: 'ChessCom',
        icon: Icons.language_rounded,
        builder: (_) => ChessComWebViewScreen(
              onNavigate: _go,
              apiClient: apiClient,
              recordSaveService: gameRecordSaveService,
              recordOwnerUserId: _localRecordUserId,
              boardGateway: _ledSettingsBoardGateway,
              boardSettings: boardSettings,
              clockSwitchService: clockSwitchService,
              latencyProbe: widget.networkLatencyProbe,
              onBoardConnected: _markBoardConnectedInPlace,
              initialUrl: chessComResumeUrl,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
              onGameActiveChanged: _updateScreenOffGameActive,
              onFinishedRecordSaved: () {
                unawaited(_loadGameRecords());
              },
              evo2LedRefreshRequestId: _evo2LedRefreshRequestId,
            )),
    AppRouteItem(
        label: 'Clock',
        icon: Icons.timer_rounded,
        builder: (_) => ChessClockScreen(
              onNavigate: _go,
              config: otbGameConfig,
              clockSwitchService: clockSwitchService,
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'Spectator',
        icon: Icons.visibility_rounded,
        builder: (_) => SpectatorScreen(
              onNavigate: _go,
              snapshot: activeSpectatorSnapshot,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
            )),
    AppRouteItem(
        label: 'BoardSettings',
        icon: Icons.settings_input_component_rounded,
        builder: (_) => BoardSettingsScreen(
              onNavigate: _go,
              boardModel: connectedBoardModel,
              boardConnected: boardConnected,
              settings: boardSettings,
              onSettingsChanged: _updateBoardSettings,
              boardGateway: boardGateway,
              onPreviewStoredBoardGames: _previewStoredBoardGames,
              onImportStoredBoardGames: _importStoredBoardGames,
              batteryStatus: boardBatteryStatus,
              apiClient: apiClient,
              screenWakeLockService: widget.screenWakeLockService,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
            )),
    AppRouteItem(
        label: 'Editor',
        icon: Icons.dashboard_customize_rounded,
        builder: (_) => BoardEditorScreen(
              onNavigate: _go,
              boardSettings: boardSettings,
              boardGateway: _ledSettingsBoardGateway,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
              onFenChanged: _updateBoardEditorFen,
              onStartBotFromFen: _startBotGameFromEditorFen,
              onAnalyzeFen: _openBoardAnalyzerFromEditorFen,
            )),
    AppRouteItem(
        label: 'Pieces',
        icon: Icons.view_module_rounded,
        builder: (_) => PieceManagementScreen(
              onNavigate: _go,
              boardModel: connectedBoardModel,
              boardGateway: boardGateway,
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'Training',
        icon: Icons.school_rounded,
        builder: (_) => TrainingScreen(
              onNavigate: _go,
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'Career',
        icon: Icons.military_tech_rounded,
        builder: (_) => CareerScreen(
              onNavigate: _go,
              apiClient: apiClient,
              onLaunchCareerGame: _launchCareerGame,
              rematchRequest: _careerRematchRequest,
              excludedOpponentName: _careerRematchExcludedOpponent,
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'BoardAnalyzer',
        icon: Icons.analytics_rounded,
        builder: (_) => BoardAnalyzerScreen(
              onNavigate: _go,
              apiClient: apiClient,
              positionAnalyzer: widget.positionAnalyzer,
              boardGateway: _ledSettingsBoardGateway,
              boardSettings: boardSettings,
              initialFen: boardAnalyzerInitialFen,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'Courses',
        icon: Icons.ondemand_video_rounded,
        builder: (_) => InteractiveCoursesScreen(
              onNavigate: _go,
              boardGateway: _ledSettingsBoardGateway,
              boardSettings: boardSettings,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              courseService: widget.courseLessonRepository,
              progressStore: widget.courseProgressStore,
              videoAdapterFactory:
                  widget.courseVideoAdapterFactory ?? createCourseVideoAdapter,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'PuzzleStorm',
        icon: Icons.bolt_rounded,
        builder: (_) => PuzzleStormScreen(
              onNavigate: _go,
              apiClient: apiClient,
              boardGateway: _ledSettingsBoardGateway,
              boardSettings: boardSettings,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              soundEffectsEnabled: widget.soundEffectsEnabled,
              soundEffects: widget.soundEffects,
              appSoundService: widget.appSoundService,
              onPuzzleSolved: () => _claimDailyTaskReward('puzzle'),
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'PuzzleThemes',
        icon: Icons.extension_rounded,
        builder: (_) => PuzzleThemesScreen(
              onNavigate: _go,
              apiClient: apiClient,
              boardGateway: _ledSettingsBoardGateway,
              boardSettings: boardSettings,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              soundEffectsEnabled: widget.soundEffectsEnabled,
              soundEffects: widget.soundEffects,
              appSoundService: widget.appSoundService,
              onPuzzleSolved: () => _claimDailyTaskReward('puzzle'),
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'MistakeBook',
        icon: Icons.menu_book_rounded,
        builder: (_) => MistakeBookScreen(
              onNavigate: _go,
              store: mistakeBookStore,
              onOpenReportMove: _openMistakeReportMove,
              refreshToken: _mistakeBookRefreshToken,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              isChessnutClockDevice: widget.isChessnutClockDevice,
            )),
    AppRouteItem(
        label: 'Engine',
        icon: Icons.memory_rounded,
        builder: (_) => EngineLabScreen(
              onNavigate: _go,
              apiClient: apiClient,
              pgnFileLoader: widget.modelBuildPgnFileLoader ??
                  loadModelBuildPgnFilesFromDesktop,
              fileImportAvailable:
                  widget.modelBuildFileImportAvailableOverride ??
                      isDesktopModelBuildFileImportAvailable,
              onCompletedModelsChanged: _updateEngineBuildBubble,
              unseenCompletedModelIds:
                  Set<int>.unmodifiable(_unseenCompletedPersonalEngineIds),
              onModelSeen: _markPersonalEngineSeen,
              onPreviewGameRecordBuild: _startModelBuildGameRecordsPreview,
              onSubmitGameRecordBuild: _startModelBuildGameRecordsPush,
              onCheckGameRecordBuild: _checkModelBuildGameRecordsJob,
              onCancelGameRecordBuild: _cancelModelBuildGameRecordsJob,
              onSummarizeGameRecords: _summarizeRemoteGameRecords,
              onSearchGameRecords: _searchModelBuildGameRecords,
              lc0WeightLibraryStore: lc0WeightLibraryStore,
            )),
    AppRouteItem(
        label: 'Points',
        icon: Icons.auto_awesome_rounded,
        builder: (_) => PointsScreen(
              onNavigate: _go,
              apiClient: apiClient,
              initialBalance: _walletBalanceSnapshot,
            )),
    AppRouteItem(
        label: 'Account',
        icon: Icons.person_rounded,
        builder: (_) => AccountScreen(
              onNavigate: _go,
              apiClient: apiClient,
              lichessAuthorizationPresenter:
                  widget.lichessAuthorizationPresenter,
              session: apiClient.session is ChessnutLoginSession
                  ? apiClient.session as ChessnutLoginSession
                  : null,
              showAccountSwitcher: _supportsAccountSwitcher,
              onSessionUpdated: (session) {
                setState(() {
                  apiClient.session = session;
                });
                unawaited(_refreshOngoingLichessGames());
                final refreshToken = session.refreshToken;
                if (refreshToken != null && refreshToken.trim().isNotEmpty) {
                  sessionStore
                      .write(
                        StoredChessnutSession(
                          userId: session.userId,
                          refreshToken: refreshToken,
                        ),
                      )
                      .ignore();
                }
              },
            )),
    if (_supportsAccountSwitcher)
      AppRouteItem(
          label: 'AccountSwitcher',
          icon: Icons.switch_account_rounded,
          builder: (_) => AccountSwitcherScreen(
                onNavigate: _go,
                store: accountSwitcherStore,
                currentUserId: apiClient.session?.userId ?? 0,
                currentAccount: apiClient.session is ChessnutLoginSession
                    ? SavedChessnutAccount.fromSession(
                        apiClient.session! as ChessnutLoginSession,
                      )
                    : null,
                onAddAccount: () => _go('Auth'),
                onSelectAccount: _switchSavedAccount,
              )),
    AppRouteItem(
        label: 'Analysis',
        icon: Icons.analytics_rounded,
        builder: (_) => AnalysisScreen(
              onNavigate: _go,
              apiClient: apiClient,
              positionAnalyzer: widget.positionAnalyzer,
              boardGateway: _playBoardGateway,
              boardSettings: boardSettings,
              showBoardCoordinates: widget.boardCoordinatesEnabled,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              attachedPgn: analysisPgn,
              reviewBackTarget: analysisReviewBackTarget,
              reportCacheKey: analysisReportCacheKey,
              initialReportPly: analysisInitialPly,
              attachedCommentId: analysisCommentId,
              reportCacheStore: analysisReportCacheStore,
              onStartReview: (pgn) => _openAnalysis(pgn: pgn),
              onOpenLastGame: _openLastFinishedAnalysis,
              pgnFileLoader: widget.analysisPgnFileLoader ??
                  loadAnalysisPgnFileFromDesktop,
              onReportCacheChanged: _handleAnalysisReportCacheChanged,
              onAnalysisStarted: () => _claimDailyTaskReward('analysis'),
              onReportShared: () => _claimDailyTaskReward('share-report'),
              reportShareService:
                  widget.reportShareService ?? const SystemReportShareService(),
              initialMaia3ReviewElo:
                  botGameConfig.engineKind == BotEngineKind.maia3
                      ? botGameConfig.maiaElo
                      : 1500,
            )),
    AppRouteItem(
        label: 'Records',
        icon: Icons.history_rounded,
        builder: (_) => GameRecordScreen(
              signedIn: signedIn,
              localStore: localGameRecordStore,
              recordSaveService: gameRecordSaveService,
              localUserId: _localRecordUserId,
              records: gameRecords,
              currentSession: apiClient.session is ChessnutLoginSession
                  ? apiClient.session as ChessnutLoginSession
                  : null,
              loading: recordsLoading,
              loadingMoreRecords: recordsLoadingMore,
              hasMoreRecords: _gameRecordsHasMore,
              currentPage: _gameRecordsPage <= 0 ? 1 : _gameRecordsPage,
              totalPage: _gameRecordsTotalPage,
              totalCount: _gameRecordsTotal,
              sourceCounts: _gameRecordSourceCounts,
              errorMessage: recordsError,
              onNavigate: _go,
              onRefresh: () => _loadGameRecords(forceReload: true),
              onAutoRefreshCurrentPage: _refreshCurrentGameRecordsPage,
              onLoadRecordPage: _loadGameRecordsPage,
              onImportPgnFile: _importPgnFileFromRecords,
              reportStatuses: analysisReportStatuses,
              isChessnutClockDevice: widget.isChessnutClockDevice,
              onAnalyzeRecord: _openRecordAnalysis,
              onContinueRecord: _continueRecord,
              onDeleteRecord: _deleteGameRecord,
              onEndRecord: _endGameRecord,
              onRefreshRecordPgn: _refreshGameRecordPgn,
              onSearchRemoteRecords: _searchRemoteGameRecords,
              onFetchLichessGames: _fetchLichessHistoryGames,
              onFetchChessComGames: _fetchChessComHistoryGames,
              onImportHistoryPgnBatch: _importHistoryPgnBatch,
            )),
    AppRouteItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        builder: (_) => SettingsScreen(
              onNavigate: _go,
              themeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
              visualTheme: widget.visualTheme,
              onVisualThemeChanged: widget.onVisualThemeChanged,
              pageAnimations: widget.pageAnimations,
              onPageAnimationsChanged: widget.onPageAnimationsChanged,
              hidePageAnimationsSetting: widget.hidePageAnimationsSetting,
              isChessnutEvo2Device: widget.isChessnutEvo2Device,
              evo2ScreenOrientation: widget.evo2ScreenOrientation,
              onEvo2ScreenOrientationChanged:
                  widget.onEvo2ScreenOrientationChanged,
              boardCoordinatesEnabled: widget.boardCoordinatesEnabled,
              onBoardCoordinatesChanged: widget.onBoardCoordinatesChanged,
              keepBoardConnectedInBackground:
                  widget.keepBoardConnectedInBackground,
              onKeepBoardConnectedInBackgroundChanged:
                  _updateKeepBoardConnectedInBackground,
              soundEffectsEnabled: widget.soundEffectsEnabled,
              onSoundEffectsChanged: widget.onSoundEffectsChanged,
              moveAnnouncementEnabled: widget.moveAnnouncementEnabled,
              onMoveAnnouncementChanged: widget.onMoveAnnouncementChanged,
              visionRecognitionOnly: visionRecognitionOnly,
              onVisionRecognitionOnlyChanged: _setVisionRecognitionOnly,
              soundEffects: widget.soundEffects,
              onSoundEffectsSettingsChanged:
                  widget.onSoundEffectsSettingsChanged,
              boardSettings: boardSettings,
              onBoardSettingsChanged: _updateBoardSettings,
              languagePreference: widget.languagePreference,
              onLanguagePreferenceChanged: widget.onLanguagePreferenceChanged,
              apiClient: apiClient,
              bugReportDiagnosticsBuilder: _bugReportDiagnostics,
              onCheckForUpdates: () => _checkForAppUpdate(manual: true),
              moduleGuides: _settingsModuleGuides,
              onReplayModuleGuide: _replayModuleGuide,
              onResetModuleGuides: _resetModuleGuides,
              hidePhysicalBoardConnectionUi: widget.isChessnutEvo2Device,
            )),
  ];

  Future<void> _completeSplash() async {
    final remembered = await sessionStore.read();
    if (!mounted) return;
    if (remembered == null || !remembered.canRefresh) {
      _go('Auth');
      return;
    }

    final result = await apiClient.refreshToken(
      remembered.userId,
      remembered.refreshToken,
    );
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      final refreshed = result.data!;
      final refreshToken = refreshed.refreshToken ?? remembered.refreshToken;
      final restoredSession = refreshed.copyWith(refreshToken: refreshToken);
      await sessionStore.write(
        StoredChessnutSession(
          userId: refreshed.userId,
          refreshToken: refreshToken,
        ),
      );
      if (!mounted) return;
      _completeSignIn(restoredSession);
      return;
    }

    if (result.status.networkError != null) {
      _continueAsGuest(offlineUserId: remembered.userId);
      return;
    }

    await _handleAuthSessionExpired(userId: remembered.userId);
  }

  Future<void> _handleSessionRefreshed(ChessnutLoginSession session) async {
    final refreshToken = session.refreshToken?.trim() ?? '';
    if (refreshToken.isNotEmpty) {
      await sessionStore.write(
        StoredChessnutSession(
          userId: session.userId,
          refreshToken: refreshToken,
        ),
      );
    }
    if (_supportsAccountSwitcher) {
      await accountSwitcherStore.upsert(
        SavedChessnutAccount.fromSession(session),
      );
    }
    if (!mounted) return;
    setState(() {
      signedIn = true;
      apiClient.session = session;
    });
  }

  Future<void> _handleAuthSessionExpired({int? userId}) async {
    final expiredUserId = userId ?? apiClient.session?.userId;
    await sessionStore.clear();
    if (_supportsAccountSwitcher && expiredUserId != null) {
      unawaited(accountSwitcherStore.remove(expiredUserId));
    }
    if (!mounted) return;
    setState(() {
      signedIn = false;
      apiClient.session = null;
      _liveLichessContinueRecords = const [];
      _clearGameRecordPagingState();
      _knownCompletedPersonalEngineIds.clear();
      _unseenCompletedPersonalEngineIds.clear();
      _engineCompletionBaselineInitialized = false;
      final authIndex = routes.indexWhere((route) => route.label == 'Auth');
      if (authIndex >= 0) {
        index = authIndex;
        _recordRoute('Auth', resetStack: true, replace: false);
      }
    });
    showAppFeedback(
      context,
      authSessionExpiredMessage,
      tone: AppFeedbackTone.warning,
    );
  }

  void _showNetworkConnectionError(String message) {
    if (!mounted) return;
    showAppFeedback(
      context,
      message,
      tone: AppFeedbackTone.error,
    );
  }

  void _showAuthTokenRefreshed(String message) {
    if (!mounted) return;
    showAppFeedback(
      context,
      message,
      tone: AppFeedbackTone.info,
    );
  }

  Future<BugReportDiagnostics> _bugReportDiagnostics() async {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final installedVersion = await AppUpdateService.readInstalledVersion();
    final deviceProfile =
        await const MethodChannelDevicePerformanceService().readProfile();
    final route = _routeStack.isEmpty ? 'Unknown' : _routeStack.last;
    final hasActiveSession = apiClient.session != null;
    final currentBoardModel =
        boardConnected ? connectedBoardModel.displayName : 'Not connected';
    final generatedAt = DateTime.now().toUtc().toIso8601String();
    final log = [
      'generated_at=$generatedAt',
      'route=$route',
      'signed_in=$hasActiveSession',
      'board_connected=$boardConnected',
      'board_model=$currentBoardModel',
      'gateway_state=${boardGateway.currentState.name}',
      'gateway_model=${boardGateway.boardModel.name}',
    ].join('\n');
    return BugReportDiagnostics(
      appVersion: installedVersion.version,
      appBuildNumber: installedVersion.buildNumber,
      platform: AppUpdateService.currentPlatformName(),
      locale: locale,
      route: route,
      boardModel: currentBoardModel,
      boardConnected: boardConnected,
      signedIn: hasActiveSession,
      log: log,
      generatedAt: generatedAt,
      deviceManufacturer: deviceProfile?.manufacturer ?? '',
      deviceModel: deviceProfile?.model ?? '',
      osVersion: deviceProfile?.osVersion ?? '',
      osSdk: deviceProfile?.sdkInt ?? 0,
    );
  }

  void _go(String label) {
    if (label == 'Records' && routes[index].label == 'Records') {
      unawaited(_loadGameRecords());
    }
    _navigate(label);
  }

  void _navigate(
    String label, {
    bool resetStack = false,
    bool replace = false,
    bool clearAnalysisPgn = true,
  }) {
    if (label == 'Back') {
      _goBack();
      return;
    }
    if (widget.isChessnutEvo2Device && label == 'ConnectBoard') {
      if (routes[index].label != 'Home') {
        _navigate(
          'Home',
          resetStack: resetStack,
          replace: replace,
          clearAnalysisPgn: clearAnalysisPgn,
        );
      }
      return;
    }
    if (widget.isChessnutEvo2Device && label == 'DisconnectBoard') {
      return;
    }
    final shouldResetPostGameAnalysis = routes[index].label == 'Analysis' &&
        label == 'Home' &&
        analysisPgn != null &&
        analysisReviewBackTarget == 'Home';
    final effectiveResetStack = resetStack || shouldResetPostGameAnalysis;
    final currentLabel = routes[index].label;
    if (label == 'BoardAnalyzer' && currentLabel != 'Editor') {
      boardAnalyzerInitialFen = chessnutStandardStartFen;
    }
    final shouldClearPendingBoardEditorRequest =
        currentLabel == 'Bot' && label != 'Bot' && label != 'Play' ||
            label == 'Bot' && currentLabel != 'Editor';
    if (routes[index].label == 'Play' && label != 'Play') {
      _clearTransientBotEditorConfig();
    }
    if (!effectiveResetStack && !replace && _isImmediatePreviousRoute(label)) {
      _goBack();
      return;
    }
    if (label == 'Career') {
      final careerRecord = _activeContinueCareerRecord;
      if (careerRecord != null) {
        _continueBotRecord(careerRecord);
        return;
      }
    }
    if (label == 'Analysis') {
      if (clearAnalysisPgn) {
        analysisPgn = null;
        analysisReportCacheKey = null;
        analysisReviewBackTarget = 'Analysis';
        analysisInitialPly = null;
        analysisCommentId = 0;
      }
    }
    if (label == 'Home') {
      signedIn = apiClient.session != null;
    }
    if (currentLabel == 'Bot' && label != 'Bot') {
      _returnHomeAfterPostGameBotSettings = false;
    }
    if (label == 'Auth') {
      signedIn = false;
      apiClient.session = null;
      _offlineRecordUserId = null;
      _activeLocalGameRecord = null;
      _localContinueBotRecord = null;
      unawaited(_reloadLocalGameRecords());
      _liveLichessContinueRecords = const [];
      _knownCompletedPersonalEngineIds.clear();
      _unseenCompletedPersonalEngineIds.clear();
      _engineCompletionBaselineInitialized = false;
      unawaited(sessionStore.clear());
    }
    if (label == 'DisconnectBoard') {
      _disconnectBoard();
      return;
    }
    if (label == 'Pieces' && !connectedBoardModel.hasPieceManagement) return;
    final target = routes.indexWhere((route) => route.label == label);
    if (target >= 0) {
      setState(() {
        if (shouldClearPendingBoardEditorRequest) {
          boardEditorBotRequestId = 0;
        }
        if (routes[target].label != routes[index].label) {
          _suppressedAutoGuideRouteLabel = null;
        }
        index = target;
        _recordRoute(label, resetStack: effectiveResetStack, replace: replace);
      });
      if (label == 'Home') {
        unawaited(_clearPhysicalBoardLightsForHome());
        unawaited(_refreshOngoingLichessGames());
      }
      if (label == 'Records') {
        if (gameRecords.isEmpty && _gameRecordsPage == 0) {
          _loadGameRecords();
        }
      }
      if (label == 'DailyTasks') {
        unawaited(_refreshWalletTaskState());
      }
      _syncWidgetVisionPlayService();
      _scheduleCurrentRouteGuideCheck();
    }
  }

  void _goBack() {
    final currentLabel = routes[index].label;
    if (currentLabel == 'Analysis') {
      unawaited(_loadAnalysisReportStatuses());
      if (analysisPgn != null && analysisReviewBackTarget == 'Home') {
        _navigate('Home', resetStack: true);
        return;
      }
    }
    if (currentLabel == 'Play') {
      _clearTransientBotEditorConfig();
    }
    if (currentLabel == 'Bot' && boardEditorBotRequestId != 0) {
      setState(() => boardEditorBotRequestId = 0);
    }
    if (currentLabel == 'Bot' && _returnHomeAfterPostGameBotSettings) {
      _returnHomeAfterPostGameBotSettings = false;
      _navigate('Home', resetStack: true);
      return;
    }
    if (_routeStack.length > 1 && _routeStack.last == currentLabel) {
      _routeStack.removeLast();
      final previousLabel = _routeStack.last;
      final target = routes.indexWhere((route) => route.label == previousLabel);
      if (target >= 0) {
        setState(() {
          if (routes[target].label != routes[index].label) {
            _suppressedAutoGuideRouteLabel = null;
          }
          index = target;
        });
        if (previousLabel == 'Home') {
          unawaited(_clearPhysicalBoardLightsForHome());
          unawaited(_refreshOngoingLichessGames());
        }
        if (previousLabel == 'Records') {
          _loadGameRecords();
        }
        if (previousLabel == 'DailyTasks') {
          unawaited(_refreshWalletTaskState());
        }
        _syncWidgetVisionPlayService();
        _scheduleCurrentRouteGuideCheck();
        return;
      }
    }

    final fallback = _fallbackBackRoute(currentLabel);
    if (fallback == null || fallback == currentLabel) return;
    _navigate(fallback, replace: true);
  }

  bool _isImmediatePreviousRoute(String label) {
    if (_routeStack.length < 2) return false;
    final currentLabel = routes[index].label;
    return _routeStack.last == currentLabel &&
        _routeStack[_routeStack.length - 2] == label;
  }

  void _recordRoute(
    String label, {
    required bool resetStack,
    required bool replace,
  }) {
    if (resetStack) {
      _routeStack
        ..clear()
        ..add(label);
      return;
    }
    if (_routeStack.isEmpty) {
      _routeStack.add(label);
      return;
    }
    if (replace) {
      _routeStack[_routeStack.length - 1] = label;
      return;
    }
    if (_routeStack.last != label) {
      _routeStack.add(label);
    }
  }

  String? _fallbackBackRoute(String label) {
    return switch (label) {
      'Splash' || 'Auth' || 'Home' => null,
      'Bot' || 'Online' || 'OtbSetup' => 'Setup',
      'ChessCom' => 'Online',
      'Clock' => 'OtbSetup',
      'Play' => 'Setup',
      'Spectator' => 'Play',
      'Editor' || 'Pieces' || 'HardwareTest' => 'BoardSettings',
      'Courses' ||
      'BoardAnalyzer' ||
      'PuzzleStorm' ||
      'PuzzleThemes' ||
      'MistakeBook' =>
        'Training',
      'Career' => 'Home',
      _ => 'Home',
    };
  }

  bool _canUseIosBackSwipe(String label) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    if (label == 'Play' || label == 'ChessCom') return false;
    if (label == 'Splash' || label == 'Auth' || label == 'Home') return false;
    if (_routeStack.length > 1 && _routeStack.last == label) return true;
    final fallback = _fallbackBackRoute(label);
    return fallback != null && fallback != label;
  }

  void _handleIosBackSwipeStart(DragStartDetails details) {
    _iosBackSwipeTriggered = false;
    _iosBackSwipeDistance = 0;
  }

  void _handleIosBackSwipeUpdate(DragUpdateDetails details) {
    if (_iosBackSwipeTriggered) return;
    final primaryDelta = details.primaryDelta ?? details.delta.dx;
    _iosBackSwipeDistance = math.max(0, _iosBackSwipeDistance + primaryDelta);
    if (_iosBackSwipeDistance >= _iosBackSwipeCommitDistance) {
      _completeIosBackSwipe();
    }
  }

  void _handleIosBackSwipeEnd(DragEndDetails details) {
    if (_iosBackSwipeTriggered) return;
    final velocity = details.primaryVelocity ?? 0;
    final isCommitted =
        _iosBackSwipeDistance >= _iosBackSwipeCommitDistance * 0.66 &&
            velocity >= _iosBackSwipeFlingVelocity;
    if (isCommitted) {
      _completeIosBackSwipe();
      return;
    }
    _iosBackSwipeDistance = 0;
  }

  void _completeIosBackSwipe() {
    _iosBackSwipeTriggered = true;
    _iosBackSwipeDistance = 0;
    _goBack();
  }

  void _continueAsGuest({int? offlineUserId}) {
    final target = routes.indexWhere((route) => route.label == 'Home');
    if (target < 0) return;
    setState(() {
      signedIn = false;
      apiClient.session = null;
      _offlineRecordUserId = offlineUserId;
      _clearGameRecordPagingState();
      _liveLichessContinueRecords = const [];
      index = target;
      _recordRoute('Home', resetStack: true, replace: false);
    });
    unawaited(_clearPhysicalBoardLightsForHome());
    unawaited(_loadLastBotGameConfig());
    unawaited(_reloadLocalGameRecords());
    _syncHomeWidgetSnapshot();
    unawaited(_applyPendingHomeWidgetAction());
  }

  void _completeSignIn(
    ChessnutLoginSession session, {
    bool renewAccountValidity = false,
  }) {
    if (_supportsAccountSwitcher) {
      unawaited(
        accountSwitcherStore.upsert(
          SavedChessnutAccount.fromSession(session),
          renewValidity: renewAccountValidity,
        ),
      );
    }
    setState(() {
      signedIn = true;
      apiClient.session = session;
      _liveLichessContinueRecords = const [];
      _offlineRecordUserId = null;
      _localContinueBotRecord = null;
      _activeLocalGameRecord = null;
      recordsError = null;
      _clearGameRecordPagingState();
      _walletBalanceSnapshot = null;
      _dailyCheckInClaimed = null;
      _claimedDailyTaskKeys.clear();
      _dailyTaskRewardClaimsDone.clear();
      _dailyTaskRewardClaimsInFlight.clear();
      _knownCompletedPersonalEngineIds.clear();
      _unseenCompletedPersonalEngineIds.clear();
      _engineCompletionBaselineInitialized = false;
    });
    unawaited(_loadLastBotGameConfig());
    unawaited(_loadGameRecords());
    unawaited(_reloadLocalGameRecords());
    unawaited(_refreshOngoingLichessGames());
    _navigate('Home', resetStack: true);
    _syncHomeWidgetSnapshot();
    unawaited(_applyPendingHomeWidgetAction());
  }

  Future<bool> _switchSavedAccount(SavedChessnutAccount account) async {
    final result = await apiClient.refreshToken(
      account.userId,
      account.refreshToken,
    );
    if (!mounted || !result.isSuccess || result.data == null) return false;
    final refreshed = result.data!;
    final session =
        refreshed.refreshToken == null || refreshed.refreshToken!.trim().isEmpty
            ? refreshed.copyWith(refreshToken: account.refreshToken)
            : refreshed;
    await sessionStore.write(
      StoredChessnutSession(
        userId: session.userId,
        refreshToken: session.refreshToken ?? account.refreshToken,
      ),
    );
    _completeSignIn(session);
    return true;
  }

  void _updateEngineBuildBubble(Set<int> completedModelIds) {
    final completed = completedModelIds.where((id) => id > 0).toSet();
    if (!_engineCompletionBaselineInitialized) {
      _engineCompletionBaselineInitialized = true;
      _knownCompletedPersonalEngineIds
        ..clear()
        ..addAll(completed);
      _unseenCompletedPersonalEngineIds.removeWhere(
        (id) => !completed.contains(id),
      );
      return;
    }
    final newlyCompleted =
        completed.difference(_knownCompletedPersonalEngineIds);
    _knownCompletedPersonalEngineIds
      ..clear()
      ..addAll(completed);
    _unseenCompletedPersonalEngineIds.removeWhere(
      (id) => !completed.contains(id),
    );
    if (newlyCompleted.isEmpty) return;
    if (!mounted) {
      _unseenCompletedPersonalEngineIds.addAll(newlyCompleted);
      return;
    }
    setState(() {
      _unseenCompletedPersonalEngineIds.addAll(newlyCompleted);
    });
  }

  void _markPersonalEngineSeen(int modelId) {
    if (modelId <= 0 ||
        !_unseenCompletedPersonalEngineIds.contains(modelId) ||
        !mounted) {
      return;
    }
    setState(() {
      _unseenCompletedPersonalEngineIds.remove(modelId);
    });
  }

  Future<void> _claimDailyTaskReward(String taskKey) async {
    if (!signedIn || apiClient.session == null) return;
    if (_dailyTaskRewardClaimsDone.contains(taskKey) ||
        _dailyTaskRewardClaimsInFlight.contains(taskKey)) {
      return;
    }
    if (taskKey == 'game') {
      return;
    }
    final points = _dailyTaskPoints(taskKey);
    if (points <= 0) return;
    _dailyTaskRewardClaimsInFlight.add(taskKey);
    final result = await apiClient.claimDailyTask(
      taskKey: taskKey,
      points: points,
    );
    _dailyTaskRewardClaimsInFlight.remove(taskKey);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) return;
    _applyDailyTaskReward(taskKey, result.data!);
  }

  void _applyDailyTaskReward(String taskKey, DailyClaimResult result) {
    if (_dailyTaskRewardClaimsDone.contains(taskKey)) {
      return;
    }
    _dailyTaskRewardClaimsDone.add(taskKey);
    setState(() {
      _claimedDailyTaskKeys.add(taskKey);
      _dailyCheckInClaimed = result.claimedToday;
      final currentWallet = _walletBalanceSnapshot;
      if (currentWallet != null) {
        _walletBalanceSnapshot = WalletBalance(
          balance: result.balance,
          claimedToday: result.claimedToday,
          dailyClaimPoints: _dailyClaimPoints,
          lastClaimedAt: currentWallet.lastClaimedAt,
          memberActive: currentWallet.memberActive,
          memberExpireAt: currentWallet.memberExpireAt,
          claimedTaskKeys: _claimedDailyTaskKeys.toList(growable: false),
        );
      } else {
        _walletBalanceSnapshot = WalletBalance(
          balance: result.balance,
          claimedToday: result.claimedToday,
          dailyClaimPoints: _dailyClaimPoints,
          lastClaimedAt: '',
          memberActive: false,
          memberExpireAt: '',
          claimedTaskKeys: _claimedDailyTaskKeys.toList(growable: false),
        );
      }
    });
    final added = result.pointsAdded;
    if (added > 0) {
      showAppFeedback(
        context,
        _dailyTaskRewardMessage(taskKey, added),
        tone: AppFeedbackTone.success,
        duration: const Duration(seconds: 2),
      );
    }
  }

  int _dailyTaskPoints(String taskKey) {
    for (final task in dailyTaskSpecs) {
      if (task.key == taskKey) return dailyTaskRewardPoints(task.points);
    }
    return 0;
  }

  String _dailyTaskRewardMessage(String taskKey, int added) {
    return switch (taskKey) {
      'career' => 'Career challenge complete +$added points',
      _ => 'Daily task reward +$added',
    };
  }

  void _updateDailyTaskStateFromWallet(WalletBalance balance) {
    _updateDailyTaskState(DailyTaskStateSnapshot.fromWalletBalance(balance));
    _walletBalanceSnapshot = balance;
  }

  Future<void> _refreshWalletTaskState() async {
    if (!signedIn ||
        apiClient.session == null ||
        _walletTaskRefreshInFlight) {
      return;
    }
    _walletTaskRefreshInFlight = true;
    try {
      final result = await apiClient.walletBalance();
      if (!mounted || !result.isSuccess || result.data == null) return;
      _updateDailyTaskStateFromWallet(result.data!);
    } finally {
      _walletTaskRefreshInFlight = false;
    }
  }

  void _updateDailyTaskState(DailyTaskStateSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _dailyCheckInClaimed = snapshot.claimedToday;
      _dailyClaimPoints = dailyCheckInRewardPoints;
      _claimedDailyTaskKeys
        ..clear()
        ..addAll(snapshot.claimedTaskKeys);
      _dailyTaskRewardClaimsDone
        ..clear()
        ..addAll(snapshot.claimedTaskKeys);
      final currentWallet = _walletBalanceSnapshot;
      if (currentWallet != null) {
        _walletBalanceSnapshot = WalletBalance(
          balance: snapshot.walletBalance ?? currentWallet.balance,
          claimedToday: snapshot.claimedToday,
          dailyClaimPoints: _dailyClaimPoints,
          lastClaimedAt: currentWallet.lastClaimedAt,
          memberActive: currentWallet.memberActive,
          memberExpireAt: currentWallet.memberExpireAt,
          claimedTaskKeys: _claimedDailyTaskKeys.toList(growable: false),
        );
      }
    });
  }

  GameRecord? get _activeContinueRecord {
    return _activeContinueOnlineRecord ??
        _activeContinueBotRecord ??
        _activeContinueOtbRecord;
  }

  GameRecord? get _activeContinueOnlineRecord {
    final records = _activeContinueOnlineRecords;
    return records.isEmpty ? null : records.first;
  }

  List<GameRecord> get _activeContinueOnlineRecords =>
      _liveLichessContinueRecords
          .where(
            (record) =>
                record.canContinueLichessGame &&
                !_dismissedContinueRecordKeys.contains(
                  _continueRecordKey(record),
                ),
          )
          .toList(growable: false);

  GameRecord? get _activeContinueBotRecord {
    final localRecord = _localContinueBotRecord;
    if (localRecord != null &&
        !_dismissedContinueRecordKeys.contains(
          _continueRecordKey(localRecord),
        ) &&
        localRecord.canContinueBotGame) {
      return localRecord;
    }
    for (final record in _availableContinueRecords) {
      if (_dismissedContinueRecordKeys.contains(_continueRecordKey(record))) {
        continue;
      }
      if (record.canContinueBotGame) return record;
    }
    return null;
  }

  List<GameRecord> get _activeContinueLocalRecords {
    final records = <GameRecord>[];
    final keys = <String>{};

    void add(GameRecord record) {
      if (!record.canContinueBotGame && !record.canContinueOtbGame) return;
      final key = _continueRecordKey(record);
      if (_dismissedContinueRecordKeys.contains(key) || !keys.add(key)) {
        return;
      }
      records.add(record);
    }

    final localRecord = _localContinueBotRecord;
    if (localRecord != null) add(localRecord);
    for (final record in _availableContinueRecords) {
      add(record);
    }
    return records;
  }

  GameRecord? get _activeContinueCareerRecord {
    for (final record in gameRecords) {
      if (_dismissedContinueRecordKeys.contains(_continueRecordKey(record))) {
        continue;
      }
      if (record.canContinueBotGame && _isCareerRecord(record)) return record;
    }
    return null;
  }

  GameRecord? get _activeContinueOtbRecord {
    for (final record in _availableContinueRecords) {
      if (_dismissedContinueRecordKeys.contains(_continueRecordKey(record))) {
        continue;
      }
      if (record.canContinueOtbGame) return record;
    }
    return null;
  }

  String _continueRecordKey(GameRecord record) {
    if (record.chessnutGameId.isNotEmpty) {
      return 'game:${record.chessnutGameId}';
    }
    if (record.canContinueLichessGame) {
      return 'lichess:${record.lichessGameId.toLowerCase()}';
    }
    final id = record.pgnId;
    if (id != null) return 'pgn:$id';
    final shareId = record.shareId;
    if (shareId != null && shareId.isNotEmpty) return 'share:$shareId';
    return 'pgn:${record.playMode}:${record.pgn.hashCode}';
  }

  Iterable<GameRecord> get _availableContinueRecords sync* {
    for (final local in _localGameRecords) {
      if (!local.isSynced || local.changedSinceUpload) yield local.record;
    }
    yield* gameRecords;
  }

  Future<void> _reloadLocalGameRecords() async {
    final generation = ++_localRecordLoadGeneration;
    try {
      final records = await localGameRecordStore.list();
      if (!mounted || generation != _localRecordLoadGeneration) {
        return;
      }
      setState(() => _localGameRecords = records);
      _syncHomeWidgetSnapshot();
    } catch (_) {
      // The archive page exposes read failures and the save service exposes
      // write failures. Startup must remain usable if storage is unavailable.
    }
  }

  Future<void> Function(GameRecord) _recordSavedCallback() {
    final userId = apiClient.session?.userId;
    return (record) async {
      if (!mounted) return;
      if (record.localRecordId.isNotEmpty) {
        await _reloadLocalGameRecords();
        if (mounted) _clearLocalBotContinueRecord(record);
      } else if (apiClient.session?.userId == userId) {
        await _handleGameRecordSaved(record);
      }
    };
  }

  bool _isCareerRecord(GameRecord record) {
    return _careerModeFromRecordHeaders(_pgnHeaders(record.pgn)) != null;
  }

  void _refreshAfterLeavingLichessGame(GameRecord _) {
    unawaited(_refreshOngoingLichessGames());
  }

  void _storeLocalBotContinueRecord(GameRecord record) {
    setState(() => _localContinueBotRecord = record);
    _syncHomeWidgetSnapshot();
  }

  void _clearLocalBotContinueRecord(GameRecord savedRecord) {
    final localRecord = _localContinueBotRecord;
    if (localRecord == null) return;
    final sameRecord = savedRecord.chessnutGameId.isNotEmpty &&
        savedRecord.chessnutGameId == localRecord.chessnutGameId;
    if (!sameRecord || savedRecord.gameStep < localRecord.gameStep) return;
    setState(() => _localContinueBotRecord = null);
    _syncHomeWidgetSnapshot();
  }

  void _removeOngoingLichessGame(String gameId) {
    final normalized = gameId.trim().toLowerCase();
    final records = _liveLichessContinueRecords
        .where(
          (record) => record.lichessGameId.toLowerCase() != normalized,
        )
        .toList(growable: false);
    if (records.length == _liveLichessContinueRecords.length) return;
    setState(() => _liveLichessContinueRecords = records);
    _syncHomeWidgetSnapshot();
  }

  void _dismissContinueRecord(GameRecord record) {
    final key = _continueRecordKey(record);
    setState(() {
      _dismissedContinueRecordKeys.add(key);
    });
    unawaited(_persistDismissedContinueRecordKeys());
  }

  Future<void> _loadDismissedContinueRecordKeys() async {
    final dismissedKeys = AppSharedPreferences.get<List<String>>(
      AppSettingKeys.dismissedContinueRecordKeys,
    );
    if (!mounted) return;
    setState(() {
      _dismissedContinueRecordKeys
        ..clear()
        ..addAll(dismissedKeys);
    });
  }

  Future<void> _loadAppUpdateReminder() async {
    final deferredUntilText = AppSharedPreferences.get<String>(
      AppSettingKeys.updateDeferredUntil,
    );
    final reminder = AppUpdateReminderState(
      deferredVersion: AppSharedPreferences.get<String>(
        AppSettingKeys.updateDeferredVersion,
      ),
      deferredUntil: DateTime.tryParse(deferredUntilText),
      ignoredVersion: AppSharedPreferences.get<String>(
        AppSettingKeys.updateIgnoredVersion,
      ),
    );
    if (!mounted) return;
    setState(() => _appUpdateReminder = reminder);
  }

  Future<void> _ensureAppUpdateReminderLoaded() {
    return _appUpdateReminderLoadFuture ??= _loadAppUpdateReminder();
  }

  Future<void> _persistAppUpdateReminder(
    AppUpdateReminderState reminder,
  ) async {
    setState(() => _appUpdateReminder = reminder);
    AppSharedPreferences.set(
      AppSettingKeys.updateDeferredVersion,
      reminder.deferredVersion,
    );
    AppSharedPreferences.set(
      AppSettingKeys.updateDeferredUntil,
      reminder.deferredUntil?.toIso8601String() ?? '',
    );
    AppSharedPreferences.set(
      AppSettingKeys.updateIgnoredVersion,
      reminder.ignoredVersion,
    );
  }

  Future<void> _loadModuleGuideSeenIds() async {
    final seenIds = AppSharedPreferences.get<List<String>>(
      AppSettingKeys.moduleGuideSeenIds,
    );
    var initialGuideCompleted = AppSharedPreferences.get<bool>(
      AppSettingKeys.initialGuideAutoPromptCompleted,
    );
    // Migrate installations that viewed the initial Home guide before its
    // install-wide completion marker was introduced.
    if (!initialGuideCompleted && seenIds.contains('home')) {
      initialGuideCompleted = true;
      AppSharedPreferences.set(
        AppSettingKeys.initialGuideAutoPromptCompleted,
        true,
      );
    }
    if (!mounted) return;
    setState(() {
      _seenModuleGuideIds = seenIds.toSet();
      _initialGuideAutoPromptCompleted = initialGuideCompleted;
      _moduleGuidePreferencesLoaded = true;
    });
    _scheduleCurrentRouteGuideCheck();
  }

  void _scheduleCurrentRouteGuideCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowCurrentRouteGuide();
    });
  }

  void _maybeShowCurrentRouteGuide() {
    if (!mounted || !_moduleGuidePreferencesLoaded) return;
    if (_usesWindowsGuideLayout && _moduleGuideReplayInProgress) return;
    final definition = _currentRouteModuleGuideDefinition();
    if (definition == null) return;
    if (definition.id == 'home' && _initialGuideAutoPromptCompleted) return;
    if (_usesWindowsGuideLayout &&
        _suppressedAutoGuideRouteLabel == definition.routeLabel) {
      return;
    }
    if (_seenModuleGuideIds.contains(definition.id)) return;
    unawaited(_showModuleGuide(definition, markSeenWhenClosed: true));
  }

  ModuleGuideDefinition? _currentRouteModuleGuideDefinition() {
    final label = routes[index].label;
    if (label == 'Play') {
      final playRoute = switch (gameMode) {
        GameLaunchMode.bot => 'Play:bot',
        GameLaunchMode.lichess ||
        GameLaunchMode.chesscom =>
          _usesWindowsGuideLayout ? null : 'Play:online',
        GameLaunchMode.otb => 'Play:otb',
        GameLaunchMode.clock => 'Clock',
      };
      if (playRoute == null) return null;
      return _platformModuleGuide(moduleGuideDefinitionForRoute(playRoute));
    }
    return _platformModuleGuide(moduleGuideDefinitionForRoute(label));
  }

  List<ModuleGuideDefinition> get _settingsModuleGuides {
    final guides = _usesWindowsGuideLayout
        ? moduleGuideDefinitions
            .where((guide) => guide.id != 'online_match_room')
        : moduleGuideDefinitions;
    return guides
        .map(_platformModuleGuide)
        .whereType<ModuleGuideDefinition>()
        .toList(growable: false);
  }

  ModuleGuideDefinition? _platformModuleGuide(ModuleGuideDefinition? guide) {
    if (guide == null) return null;
    final deviceGuide = moduleGuideDefinitionForDevice(
      guide,
      isChessnutClockDevice: widget.isChessnutClockDevice,
    );
    if (!_usesWindowsGuideLayout) return deviceGuide;
    return switch (deviceGuide.id) {
      'board_settings' => deviceGuide.copyWith(
          steps: [
            deviceGuide.steps[0],
            deviceGuide.steps[1],
            const ModuleGuideStep(
              title: 'Board lights',
              body:
                  'Control the board LED hints used while setting up and playing.',
              targetKey: ValueKey('board-settings-lights-section'),
            ),
          ],
        ),
      'board_editor' => deviceGuide.copyWith(
          steps: const [
            ModuleGuideStep(
              title: 'Board status',
              body:
                  'Check whether the physical board is connected and syncing.',
              targetKey: ValueKey('board-editor-board-section'),
            ),
            ModuleGuideStep(
              title: 'Edit controls',
              body:
                  'Use these controls to read from the board, send FEN, and adjust position settings.',
              targetKey: ValueKey('board-editor-controls-section'),
            ),
            ModuleGuideStep(
              title: 'Start from here',
              body:
                  'Start a bot game from the edited position when it is ready.',
              targetKey: ValueKey('board-editor-actions-section'),
            ),
          ],
        ),
      _ => deviceGuide,
    };
  }

  Future<void> _replayModuleGuide(ModuleGuideDefinition definition) async {
    if (!_usesWindowsGuideLayout) {
      final ready = await _prepareModuleGuideReplayTarget(definition);
      if (!ready || !mounted) return;
      await _showModuleGuide(definition, markSeenWhenClosed: false);
      return;
    }
    _moduleGuideReplayInProgress = true;
    try {
      final ready = await _prepareModuleGuideReplayTarget(definition);
      if (!ready || !mounted) return;
      await _showModuleGuide(definition, markSeenWhenClosed: false);
    } finally {
      _moduleGuideReplayInProgress = false;
      _suppressedAutoGuideRouteLabel =
          _currentRouteModuleGuideDefinition()?.routeLabel;
    }
  }

  Future<bool> _prepareModuleGuideReplayTarget(
    ModuleGuideDefinition definition,
  ) async {
    if (_currentRouteModuleGuideDefinition()?.id == definition.id) {
      return true;
    }
    final playMode = _playModeForModuleGuideRoute(definition.routeLabel);
    if (playMode != null) {
      setState(() {
        gameMode = playMode;
        activeGameRecordId = null;
        activeGameShareId = null;
      });
      _navigate('Play');
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return _currentRouteModuleGuideDefinition()?.id == definition.id;
    }

    final targetRoute = _replayRouteForModuleGuide(definition);
    if (targetRoute == null) return false;
    if (routes[index].label != targetRoute) {
      _navigate(targetRoute, resetStack: targetRoute == 'Home');
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return _currentRouteModuleGuideDefinition()?.id == definition.id;
  }

  String? _replayRouteForModuleGuide(ModuleGuideDefinition definition) {
    return switch (definition.routeLabel) {
      'Clock' => 'Clock',
      final routeLabel when routes.any((route) => route.label == routeLabel) =>
        routeLabel,
      _ => null,
    };
  }

  GameLaunchMode? _playModeForModuleGuideRoute(String routeLabel) {
    return switch (routeLabel) {
      'Play:bot' => GameLaunchMode.bot,
      'Play:online' => GameLaunchMode.lichess,
      'Play:otb' => GameLaunchMode.otb,
      _ => null,
    };
  }

  Future<void> _resetModuleGuides() async {
    if (!mounted) return;
    setState(() {
      _seenModuleGuideIds = const {};
      _initialGuideAutoPromptCompleted = false;
      _suppressedAutoGuideRouteLabel = null;
    });
    AppSharedPreferences.set<List<String>>(
      AppSettingKeys.moduleGuideSeenIds,
      const [],
    );
    AppSharedPreferences.set(
      AppSettingKeys.initialGuideAutoPromptCompleted,
      false,
    );
    _scheduleCurrentRouteGuideCheck();
  }

  Future<void> _showModuleGuide(
    ModuleGuideDefinition definition, {
    required bool markSeenWhenClosed,
  }) async {
    if (!mounted || _activeModuleGuideId != null) return;
    _activeModuleGuideId = definition.id;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (dialogContext) => _ModuleGuideDialog(
        definition: definition,
        hostContext: context,
        hideMissingTargetSpotlight:
            _usesWindowsGuideLayout || _usesSafeAreaAdjustedGuideLayout,
        onDone: () => Navigator.of(dialogContext).pop(),
      ),
    );
    if (!mounted) {
      _activeModuleGuideId = null;
      return;
    }
    _activeModuleGuideId = null;
    if (!markSeenWhenClosed) return;
    if (definition.id == 'home') {
      setState(() => _initialGuideAutoPromptCompleted = true);
      AppSharedPreferences.set(
        AppSettingKeys.initialGuideAutoPromptCompleted,
        true,
      );
    }
    if (_seenModuleGuideIds.contains(definition.id)) return;
    final next = Set<String>.from(_seenModuleGuideIds)..add(definition.id);
    setState(() => _seenModuleGuideIds = next);
    AppSharedPreferences.set<List<String>>(
      AppSettingKeys.moduleGuideSeenIds,
      next.toList(growable: false),
    );
  }

  Future<void> _loadLastBotGameConfig() async {
    final config = _savedUserBotGameConfigs()[_botPreferenceKey] ??
        _savedLastBotGameConfig();
    if (!mounted || config == null) return;
    final rememberedConfig = _rememberableBotGameConfig(config);
    setState(() => botGameConfig = rememberedConfig);
    if (_isBoardEditorBotGameConfig(config)) {
      unawaited(_persistLastBotGameConfig(rememberedConfig));
    }
  }

  Future<void> _loadAnalysisReportStatuses() async {
    final statuses = await analysisReportCacheStore.readStatuses();
    if (!mounted) return;
    setState(() => analysisReportStatuses = statuses);
  }

  Future<void> _syncMistakeBookFromReports() async {
    final preferences = await appPreferencesStore.read();
    await mistakeBookStore.syncFromAnalysisReports(preferences.analysisReports);
  }

  List<GameRecord> _filterDeletedGameRecords(List<GameRecord> records) {
    if (_deletedGameRecordIds.isEmpty) return records;
    return records.where((record) {
      final pgnId = record.pgnId;
      return pgnId == null || !_deletedGameRecordIds.contains(pgnId);
    }).toList(growable: false);
  }

  Future<void> _persistLastBotGameConfig(BotGameConfig config) async {
    final rememberedConfig = _rememberableBotGameConfig(config);
    final configs = _savedUserBotGameConfigs();
    configs[_botPreferenceKey] = rememberedConfig;
    AppSharedPreferences.set(
      AppSettingKeys.lastBotGameConfig,
      jsonEncode(rememberedConfig.toJson()),
    );
    AppSharedPreferences.set(
      AppSettingKeys.userBotGameConfigs,
      jsonEncode({
        for (final entry in configs.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  BotGameConfig? _savedLastBotGameConfig() {
    final encoded = AppSharedPreferences.get<String>(
      AppSettingKeys.lastBotGameConfig,
    );
    if (encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map<String, dynamic>
          ? BotGameConfig.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, BotGameConfig> _savedUserBotGameConfigs() {
    final encoded = AppSharedPreferences.get<String>(
      AppSettingKeys.userBotGameConfigs,
    );
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return {};
      final configs = <String, BotGameConfig>{};
      for (final entry in decoded.entries) {
        final rawConfig = entry.value;
        if (rawConfig is! Map) continue;
        configs[entry.key.toString()] = BotGameConfig.fromJson(
          rawConfig.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      return configs;
    } catch (_) {
      return {};
    }
  }

  BotGameConfig _rememberableBotGameConfig(BotGameConfig config) {
    final rememberedConfig = config.copyWith(
      clearCareerMode: true,
      clearResumePgn: true,
    );
    if (!_isBoardEditorBotGameConfig(rememberedConfig)) {
      return rememberedConfig;
    }
    return rememberedConfig.copyWith(
      opening: standardOpeningScenario,
      startFen: chessnutStandardStartFen,
      chess960: false,
    );
  }

  bool _isBoardEditorBotGameConfig(BotGameConfig config) {
    return config.opening.id == 'board-editor-fen' ||
        config.opening.eco == 'FEN';
  }

  void _clearTransientBotEditorConfig() {
    if (boardEditorBotRequestId == 0 &&
        !_isBoardEditorBotGameConfig(botGameConfig)) {
      return;
    }
    setState(() {
      boardEditorBotRequestId = 0;
      if (_isBoardEditorBotGameConfig(botGameConfig)) {
        botGameConfig = _rememberableBotGameConfig(botGameConfig);
      }
    });
  }

  String get _botPreferenceKey {
    final userId = apiClient.session?.userId;
    if (userId != null && userId > 0) return 'user:$userId';
    return 'guest';
  }

  Future<void> _persistDismissedContinueRecordKeys() async {
    AppSharedPreferences.set<List<String>>(
      AppSettingKeys.dismissedContinueRecordKeys,
      _dismissedContinueRecordKeys.toList(growable: false),
    );
  }

  Future<void> _refreshOngoingLichessGames() async {
    if (_ongoingLichessGamesRefreshInFlight || !signedIn) return;
    if (routes[index].label == 'Play' && gameMode == GameLaunchMode.lichess) {
      return;
    }
    _ongoingLichessGamesRefreshInFlight = true;
    try {
      final tokenResult = await apiClient.getLichessToken();
      if (!mounted || !signedIn) return;
      final token = tokenResult.data?.token.trim() ?? '';
      final lichessName = tokenResult.data?.lichessName.trim() ?? '';
      if (token.isEmpty) {
        if (tokenResult.status.networkError == null) {
          setState(() => _liveLichessContinueRecords = const []);
          _syncHomeWidgetSnapshot();
        }
        return;
      }
      final service = LichessBoardService(
        token: token,
        localLichessName: lichessName,
        httpClient: apiClient.httpClient,
      );
      final games = await service.getOngoingGames();
      if (!mounted || !signedIn) return;
      if (games == null) {
        if (service.lastStatusCode == 401 || service.lastStatusCode == 403) {
          setState(() => _liveLichessContinueRecords = const []);
          _syncHomeWidgetSnapshot();
        }
        return;
      }
      final records = games
          .where((game) => game.supportsBoardApi)
          .map(
            (game) => _ongoingLichessGameRecord(
              game,
              token: token,
              lichessName: lichessName,
            ),
          )
          .toList(growable: false);
      setState(() => _liveLichessContinueRecords = records);
      _syncHomeWidgetSnapshot();
    } finally {
      _ongoingLichessGamesRefreshInFlight = false;
    }
  }

  GameRecord _ongoingLichessGameRecord(
    LichessOngoingGame game, {
    required String token,
    required String lichessName,
  }) {
    final localName = lichessName.isEmpty ? 'Lichess' : lichessName;
    final opponent = game.opponentName.isEmpty ? 'Lichess' : game.opponentName;
    final playerIsBlack = game.color == LichessPlayerSide.black;
    final whiteName = playerIsBlack ? opponent : localName;
    final blackName = playerIsBlack ? localName : opponent;
    final playerSide = playerIsBlack ? 'Black' : 'White';
    final pgn = GameNotationService.buildPgn(
      sanMoves: const [],
      event: 'Lichess online game',
      site: 'https://lichess.org/${game.gameId}',
      white: whiteName,
      black: blackName,
      result: '*',
      timeControl: '-',
      startFen: LichessBoardService.startposFen,
      extraHeaders: {
        'LichessGameId': game.gameId,
        'LichessToken': token,
        'LichessName': lichessName,
        'PlayerSide': playerSide,
        'GameStatus': '1',
        if (game.speed.isNotEmpty) 'Speed': game.speed,
        if (game.variant.isNotEmpty) 'Variant': game.variant,
      },
    );
    return GameRecord(
      result: '*',
      title: '$whiteName vs $blackName',
      subtitle: 'Lichess',
      pgn: pgn,
      playMode: 'lichess',
      gameStatus: 1,
      winId: 0,
      whiteName: whiteName,
      blackName: blackName,
      lichessGameIdOverride: game.gameId,
      lichessTokenOverride: token,
      lichessNameOverride: lichessName,
      playerColorOverride: playerSide.toLowerCase(),
      speedOverride: game.speed,
      opponentNameOverride: opponent,
    );
  }

  Future<void> _loadGameRecords({bool forceReload = false}) async {
    if (!signedIn) return;
    final activeLoad = _recordsLoadFuture;
    if (activeLoad != null) {
      if (forceReload) recordsReloadQueued = true;
      await activeLoad;
      return;
    }
    final load = _performGameRecordsLoad();
    _recordsLoadFuture = load;
    await load;
  }

  Future<void> _performGameRecordsLoad() async {
    try {
      do {
        recordsReloadQueued = false;
        await _loadGameRecordsOnce();
      } while (mounted && signedIn && recordsReloadQueued);
    } finally {
      _recordsLoadFuture = null;
      recordsReloadQueued = false;
    }
  }

  Future<void> _loadGameRecordsOnce() async {
    if (!signedIn) return;
    // A full reload supersedes page/automatic requests started before it.
    _recordsRefreshGeneration++;
    setState(() {
      recordsLoading = true;
      recordsError = null;
      _gameRecordsPage = 0;
      _gameRecordsHasMore = false;
      _gameRecordsTotal = 0;
      _gameRecordsTotalPage = 1;
      _gameRecordSourceCounts = null;
    });
    try {
      final result = await gameRecordRepository.loadRecords(
        page: 1,
        count: _gameRecordPageSize,
        deferRemotePgn: true,
      );
      if (!mounted) return;
      setState(() {
        recordsLoading = false;
        if (result.isSuccess) {
          _applyGameRecordLoadResult(result);
          gameRecords = _filterDeletedGameRecords(result.records);
        } else {
          recordsError =
              result.status.errorMessage ?? 'Unable to load records.';
        }
      });
      if (result.isSuccess) {
        unawaited(_refreshGameRecordSourceCounts());
        unawaited(_applyHydratedGameRecords(
          result.hydratedRecords,
          page: result.page,
        ));
        _syncHomeWidgetSnapshot();
        unawaited(_applyPendingHomeWidgetAction());
      }
    } finally {
      if (mounted && recordsLoading) {
        setState(() => recordsLoading = false);
      }
    }
  }

  bool _hasMoreGameRecordPages(GameRecordLoadResult result) {
    if (result.totalPage > 0) return result.page < result.totalPage;
    return result.records.length >= result.count;
  }

  Map<RecordSourceTab, int> _sourceCountsWithTotal(
    Map<RecordSourceTab, int>? current,
    int total,
  ) {
    return {
      if (current != null) ...current,
      RecordSourceTab.all: total,
    };
  }

  void _clearGameRecordPagingState() {
    gameRecords = const [];
    _gameRecordsPage = 0;
    _gameRecordsHasMore = false;
    _gameRecordsTotal = 0;
    _gameRecordsTotalPage = 1;
    _gameRecordSourceCounts = null;
  }

  void _applyGameRecordLoadResult(GameRecordLoadResult result) {
    _gameRecordsPage = result.page;
    _gameRecordsHasMore = _hasMoreGameRecordPages(result);
    _gameRecordsTotalPage = math.max(1, result.totalPage);
    _gameRecordsTotal = result.total;
    if (result.total > 0) {
      _gameRecordSourceCounts = _sourceCountsWithTotal(
        _gameRecordSourceCounts,
        result.total,
      );
    }
  }

  Future<void> _refreshGameRecordSourceCounts() async {
    if (!signedIn) return;
    final counts = await _loadLatestGameRecordSourceCounts();
    if (!mounted || !signedIn) return;
    if (counts == null) return;
    setState(() {
      final next = Map<RecordSourceTab, int>.from(
        _gameRecordSourceCounts ?? const {},
      );
      next.addAll(counts);
      final archiveTotal = next[RecordSourceTab.all] ?? 0;
      if (_gameRecordsTotal > archiveTotal) {
        next[RecordSourceTab.all] = _gameRecordsTotal;
      }
      _gameRecordSourceCounts = next;
    });
  }

  Future<Map<RecordSourceTab, int>?> _loadLatestGameRecordSourceCounts() async {
    final result = await apiClient.getGameRecordSourceCounts();
    final data = result.data;
    if (!result.isSuccess || data == null) return null;
    return {
      RecordSourceTab.all: math.max(0, data.all),
      RecordSourceTab.local: math.max(0, data.local),
      RecordSourceTab.lichess: math.max(0, data.lichess),
      RecordSourceTab.chesscom: math.max(0, data.chessCom),
    };
  }

  void _decrementGameRecordSourceCounts(GameRecord record) {
    final counts = _gameRecordSourceCounts;
    if (counts == null) return;
    final next = Map<RecordSourceTab, int>.from(counts);
    void decrement(RecordSourceTab tab) {
      final value = next[tab];
      if (value != null && value > 0) next[tab] = value - 1;
    }

    decrement(RecordSourceTab.all);
    decrement(_sourceTabForGameRecord(record));
    _gameRecordSourceCounts = next;
  }

  RecordSourceTab _sourceTabForGameRecord(GameRecord record) {
    return _sourceTabForRecordMode(record.playMode);
  }

  RecordSourceTab _sourceTabForRecordMode(String playMode) {
    final mode = playMode.trim().toLowerCase();
    if (mode.contains('lichess')) return RecordSourceTab.lichess;
    if (mode.contains('chesscom') || mode.contains('chess.com')) {
      return RecordSourceTab.chesscom;
    }
    return RecordSourceTab.local;
  }

  List<GameRecord> _mergeGameRecordLists(
    List<GameRecord> primary,
    List<GameRecord> secondary,
  ) {
    if (primary.isEmpty) return secondary;
    if (secondary.isEmpty) return primary;
    final keys = primary.map(gameAnalysisReportCacheKeyForRecord).toSet();
    return [
      ...primary,
      for (final record in secondary)
        if (keys.add(gameAnalysisReportCacheKeyForRecord(record))) record,
    ];
  }

  Future<void> _loadGameRecordsPage(int page) async {
    if (!signedIn || recordsLoading || recordsLoadingMore) return;
    final generation = _recordsRefreshGeneration;
    final targetPage =
        page.clamp(1, math.max(1, _gameRecordsTotalPage)).toInt();
    if (targetPage == _gameRecordsPage) return;
    setState(() {
      recordsLoadingMore = true;
      recordsError = null;
    });
    try {
      final result = await gameRecordRepository.loadRecords(
        page: targetPage,
        count: _gameRecordPageSize,
        deferRemotePgn: true,
      );
      if (!mounted || generation != _recordsRefreshGeneration) return;
      if (!result.isSuccess) {
        setState(() {
          recordsLoadingMore = false;
          recordsError =
              result.status.errorMessage ?? 'Unable to load records.';
        });
        return;
      }

      final remoteRecords = _filterDeletedGameRecords(result.records);
      final visibleRecords = remoteRecords;
      if (!mounted) return;
      setState(() {
        recordsLoadingMore = false;
        _applyGameRecordLoadResult(result);
        gameRecords = visibleRecords;
      });
      unawaited(_applyHydratedGameRecords(
        result.hydratedRecords,
        page: result.page,
      ));
      _syncHomeWidgetSnapshot();
    } finally {
      if (mounted && recordsLoadingMore) {
        setState(() => recordsLoadingMore = false);
      }
    }
  }

  Future<void> _refreshCurrentGameRecordsPage() async {
    if (!signedIn ||
        recordsLoading ||
        recordsLoadingMore ||
        _recordsAutoRefreshInFlight) {
      return;
    }
    _recordsAutoRefreshInFlight = true;
    final generation = _recordsRefreshGeneration;
    final page = _gameRecordsPage <= 0 ? 1 : _gameRecordsPage;
    try {
      final result = await gameRecordRepository.loadRecords(
        page: page,
        count: _gameRecordPageSize,
        deferRemotePgn: true,
      );
      if (!mounted ||
          generation != _recordsRefreshGeneration ||
          !result.isSuccess) {
        return;
      }
      setState(() {
        _applyGameRecordLoadResult(result);
        gameRecords = _filterDeletedGameRecords(result.records);
      });
      unawaited(_applyHydratedGameRecords(
        result.hydratedRecords,
        page: result.page,
      ));
      unawaited(_refreshGameRecordSourceCounts());
      _syncHomeWidgetSnapshot();
    } finally {
      _recordsAutoRefreshInFlight = false;
    }
  }

  Future<void> _handleGameRecordSaved(GameRecord savedRecord) async {
    if (!mounted) return;
    if (savedRecord.localRecordId.isNotEmpty) {
      await _reloadLocalGameRecords();
      if (mounted) _clearLocalBotContinueRecord(savedRecord);
      return;
    }
    if (gameMode == GameLaunchMode.lichess) {
      _removeOngoingLichessGame(lichessGameConfig.gameId);
      unawaited(_refreshOngoingLichessGames());
    }
    if (mounted) {
      _mergeSavedGameRecord(savedRecord);
      _clearLocalBotContinueRecord(savedRecord);
    }
    if (!signedIn) return;
    await _loadGameRecords();
    if (!mounted) return;
    _mergeSavedGameRecord(savedRecord);
    unawaited(_refreshWalletTaskState());
    _syncHomeWidgetSnapshot();
  }

  void _mergeSavedGameRecord(GameRecord savedRecord) {
    setState(() {
      final index = gameRecords.indexWhere(
        (record) =>
            savedRecord.pgnId != null && record.pgnId == savedRecord.pgnId,
      );
      if (index < 0) {
        gameRecords = [savedRecord, ...gameRecords];
      } else {
        gameRecords = [...gameRecords]..[index] = savedRecord;
      }
    });
  }

  Future<ApiResult<bool>> _deleteGameRecord(GameRecord record) async {
    final pgnId = record.pgnId;
    if (pgnId == null) {
      final key = gameAnalysisReportCacheKeyForRecord(record);
      final deleted = await analysisReportCacheStore.delete(key);
      if (!deleted) {
        return const ApiResult(
          ApiStatus.api(
            code: 404,
            message: 'This local game record was not found.',
          ),
        );
      }
      if (mounted) {
        await _loadAnalysisReportStatuses();
        await _loadGameRecords();
      }
      return const ApiResult<bool>(ApiStatus.success(), data: true);
    }
    final result = await gameRecordRepository.deleteRecord(pgnId: pgnId);
    if (result.isSuccess && mounted) {
      setState(() {
        _deletedGameRecordIds.add(pgnId);
        _decrementGameRecordSourceCounts(record);
        gameRecords = _filterDeletedGameRecords(gameRecords);
      });
      unawaited(_loadGameRecords());
    }
    return result;
  }

  Future<ApiResult<bool>> _endGameRecord(GameRecord record) async {
    final result = await gameRecordRepository.endRecord(record);
    if (result.isSuccess && mounted) {
      unawaited(_refreshWalletTaskState());
      await _loadGameRecords();
      _syncHomeWidgetSnapshot();
    }
    return result;
  }

  Future<void> _applyHydratedGameRecords(
    List<Future<GameRecord>>? hydratedRecords, {
    required int page,
  }) async {
    if (hydratedRecords == null) return;
    for (final hydratedRecord in hydratedRecords) {
      unawaited(_applyHydratedGameRecord(hydratedRecord, page: page));
    }
  }

  Future<void> _applyHydratedGameRecord(
    Future<GameRecord> hydratedRecord, {
    required int page,
  }) async {
    GameRecord record;
    try {
      record = await hydratedRecord;
    } catch (_) {
      return;
    }
    if (!mounted || _gameRecordsPage != page) return;
    final pgnId = record.pgnId;
    if (pgnId == null) return;
    final index = gameRecords.indexWhere(
      (current) => current.pgnId == pgnId && current.isPgnPending,
    );
    if (index < 0) return;
    setState(() {
      gameRecords = [...gameRecords]..[index] = record;
    });
    _syncHomeWidgetSnapshot();
  }

  Future<ApiResult<GameRecord>> _refreshGameRecordPgn(
    GameRecord record,
  ) async {
    final result = await gameRecordRepository.refreshRecordPgn(record);
    final refreshed = result.data;
    if (!mounted || !result.isSuccess || refreshed == null) return result;
    setState(() {
      gameRecords = [
        for (final current in gameRecords)
          if (current.pgnId == refreshed.pgnId) refreshed else current,
      ];
    });
    _syncHomeWidgetSnapshot();
    return result;
  }

  Future<BoardStorageImportPreview> _previewStoredBoardGames(
    List<String> rawFenSequences,
  ) async {
    final preferences = await appPreferencesStore.read();
    final service = BoardStorageImportService(
      apiClient: apiClient,
      recordsProvider: _boardStorageExistingRecords,
    );
    return service.previewStoredGames(
      rawFenSequences,
      importedKeys: preferences.importedBoardStorageKeys,
    );
  }

  Future<List<GameRecord>> _boardStorageExistingRecords() async {
    final visibleRecords = gameRecords;
    if (!signedIn || apiClient.session == null) return visibleRecords;

    const pageSize = 100;
    final remote = <GameRecord>[];
    final first = await gameRecordRepository.loadRecords(
      page: 1,
      count: pageSize,
    );
    if (!first.isSuccess) return visibleRecords;

    remote.addAll(_filterDeletedGameRecords(first.records));
    final totalPage = first.totalPage > 0
        ? first.totalPage
        : first.total > 0
            ? math.max(1, (first.total / pageSize).ceil())
            : first.records.length >= pageSize
                ? 2
                : 1;
    for (var page = 2; page <= totalPage; page++) {
      final result = await gameRecordRepository.loadRecords(
        page: page,
        count: pageSize,
      );
      if (!result.isSuccess) break;
      final records = _filterDeletedGameRecords(result.records);
      if (records.isEmpty) break;
      remote.addAll(records);
      if (result.totalPage > 0 && page >= result.totalPage) break;
    }

    return _mergeGameRecordLists(remote, visibleRecords);
  }

  Future<BoardStorageImportResult> _importStoredBoardGames({
    required bool deleteAfterImport,
  }) async {
    if (!boardConnected ||
        boardGateway.currentState != PhysicalBoardConnectionState.connected ||
        !boardGateway.supportsStoredGameImport) {
      return const BoardStorageImportResult(
        importedCount: 0,
        skippedCount: 0,
        failedCount: 1,
        importedKeys: <String>{},
        errors: ['Connect a board that supports saved game import.'],
      );
    }

    final count = await boardGateway.queryStoredGameCount();
    if (count == null) {
      return const BoardStorageImportResult(
        importedCount: 0,
        skippedCount: 0,
        failedCount: 1,
        importedKeys: <String>{},
        errors: ['Chessnut could not read the board storage count.'],
      );
    }
    if (count <= 0) {
      return const BoardStorageImportResult(
        importedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        importedKeys: <String>{},
        errors: [],
      );
    }

    final service = BoardStorageImportService(
      apiClient: apiClient,
      recordsProvider: () async => const [],
      saveService: gameRecordSaveService,
      ownerUserId: _localRecordUserId,
    );
    var imported = 0;
    var failed = 0;
    final keys = <String>{};
    final errors = <String>[];
    for (var index = 0; index < count; index++) {
      final raw = await boardGateway.peekStoredGameFile();
      if (raw == null || raw.trim().isEmpty) break;
      final parsed =
          BoardStorageImportService.parseStoredGame(rawFenSequence: raw);
      if (!parsed.isImportable) {
        failed++;
        errors.add('A board game could not be imported.');
        break;
      }
      final result = await service.importParsed([parsed]);
      imported += result.importedCount;
      failed += result.failedCount;
      keys.addAll(result.importedKeys);
      errors.addAll(result.errors);
      // Never delete the board's only copy before cloud acknowledgement or a
      // successful local transaction, including when parsing or saving fails.
      if (result.importedCount == 0 || !deleteAfterImport) break;
      if (!await boardGateway.deleteStoredGameFile()) {
        errors.add(
            'Saved game imported, but the board copy could not be deleted.');
        break;
      }
    }
    return BoardStorageImportResult(
      importedCount: imported,
      skippedCount: 0,
      failedCount: failed,
      importedKeys: keys,
      errors: errors,
    );
  }

  Future<void> _handleAnalysisReportCacheChanged() async {
    await _syncMistakeBookFromReports();
    await _loadAnalysisReportStatuses();
    unawaited(_refreshWalletTaskState());
    if (!mounted) return;
    setState(() => _mistakeBookRefreshToken++);
    if (routes[index].label == 'Records' || signedIn) {
      unawaited(_loadGameRecords());
    }
  }

  Future<void> _openAnalysis({required String pgn}) async {
    final cacheKey = gameAnalysisReportCacheKeyForPgn(pgn);
    _openAnalysisInternal(
      pgn: pgn,
      cacheKey: cacheKey,
      commentId: 0,
      backTarget: 'Analysis',
    );
  }

  Future<void> _openPostGameAnalysis({required String pgn}) async {
    final cacheKey = gameAnalysisReportCacheKeyForPgn(pgn);
    _openAnalysisInternal(
      pgn: pgn,
      cacheKey: cacheKey,
      commentId: 0,
      backTarget: 'Home',
    );
  }

  Future<void> _importPgnFileFromRecords() async {
    String? content;
    try {
      final loader =
          widget.analysisPgnFileLoader ?? loadAnalysisPgnFileFromDesktop;
      content = await loader();
    } on PlatformException catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        error.message ??
            'Unable to open this PGN file. Choose another file and try again.',
        tone: AppFeedbackTone.error,
      );
      return;
    } catch (_) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'Unable to open this PGN file. Choose another file and try again.',
        tone: AppFeedbackTone.error,
      );
      return;
    }
    if (!mounted || content == null) return;
    final pgn = content.trim();
    if (pgn.isEmpty) {
      showAppFeedback(
        context,
        'The selected PGN file is empty.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    final games = splitPgnGames(pgn, limit: historyPgnBatchLimit + 1);
    if (games.length > historyPgnBatchLimit) {
      showAppFeedback(
        context,
        AppStrings.of(context).t('You can import up to 500 games at a time.'),
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    try {
      for (final game in games) {
        final parsed = GameNotationService.parsePgn(game);
        if ((parsed.headers['White'] ?? '').trim().isEmpty ||
            (parsed.headers['Black'] ?? '').trim().isEmpty) {
          throw const FormatException('PGN is missing player names.');
        }
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        _readablePgnImportError(error.message),
        tone: AppFeedbackTone.warning,
      );
      return;
    } catch (_) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'This PGN could not be read. Check the PGN file and try again.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }

    final result = await apiClient.uploadPgnList(
      pgnList: games.join('\n\n'),
    );
    if (!mounted) return;
    final importedCount = result.data ?? 0;
    if (!result.isSuccess || importedCount <= 0) {
      showAppFeedback(
        context,
        result.status.errorMessage ??
            AppStrings.of(context).t('Unable to import selected games.'),
        tone: AppFeedbackTone.error,
      );
      return;
    }

    await _loadGameRecords();
    if (!mounted) return;
    final message = AppStrings.of(context)
        .t('Imported {count} games.')
        .replaceAll('{count}', importedCount.toString());
    showAppFeedback(context, message, tone: AppFeedbackTone.success);
  }

  String _readablePgnImportError(String message) {
    if (message.contains('no legal mainline moves')) {
      return 'This PGN has no playable moves. Check the PGN file and try again.';
    }
    if (message.contains('Illegal')) {
      return 'This PGN includes a move Chessnut cannot read. Check the move list and try again.';
    }
    return 'This PGN could not be read. Check the PGN file and try again.';
  }

  Future<void> _openRecordAnalysis(
    GameRecord record, {
    String backTarget = 'Records',
  }) async {
    final cacheKey = gameAnalysisReportCacheKeyForRecord(record);
    _openAnalysisInternal(
      pgn: record.pgn,
      cacheKey: cacheKey,
      commentId: record.commentId,
      backTarget: backTarget,
    );
  }

  void _openMistakeReportMove(MistakeBookEntry entry) {
    _openAnalysisInternal(
      pgn: entry.pgn,
      cacheKey: entry.reportKey,
      commentId: 0,
      backTarget: 'MistakeBook',
      initialPly: entry.ply,
    );
  }

  void _openAnalysisInternal({
    required String pgn,
    required String cacheKey,
    required int commentId,
    required String backTarget,
    int? initialPly,
  }) {
    final target = routes.indexWhere((route) => route.label == 'Analysis');
    if (target < 0) return;
    setState(() {
      analysisPgn = pgn;
      analysisReportCacheKey = cacheKey;
      analysisReviewBackTarget = backTarget;
      analysisInitialPly = initialPly;
      analysisCommentId = commentId;
      analysisReportStatuses = {
        ...analysisReportStatuses,
        cacheKey: analysisReportStatuses[cacheKey] ??
            const GameAnalysisReportStatus(),
      };
      index = target;
      _recordRoute('Analysis', resetStack: false, replace: false);
    });
  }

  Future<void> _openLastFinishedAnalysis() async {
    if (!signedIn) {
      showAppFeedback(
        context,
        'Sign in to view records',
        tone: AppFeedbackTone.warning,
      );
      return;
    }

    if (recordsLoading) {
      showAppFeedback(
        context,
        'Loading records',
        tone: AppFeedbackTone.info,
      );
      return;
    }

    setState(() {
      recordsLoading = true;
      recordsError = null;
    });
    final result = await gameRecordRepository.loadRecords(
      page: 1,
      count: _gameRecordPageSize,
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        recordsLoading = false;
        recordsError = result.status.errorMessage ?? 'Unable to load records.';
      });
      showAppFeedback(
        context,
        recordsError ?? 'Unable to load records.',
        tone: AppFeedbackTone.error,
      );
      return;
    }
    final records = _filterDeletedGameRecords(result.records);
    setState(() {
      recordsLoading = false;
      _applyGameRecordLoadResult(result);
      gameRecords = records;
    });
    unawaited(_refreshGameRecordSourceCounts());

    GameRecord? lastFinished;
    for (final record in records) {
      if (record.isInProgress || record.pgn.trim().isEmpty) continue;
      try {
        GameNotationService.parsePgn(record.pgn);
      } catch (_) {
        continue;
      }
      lastFinished = record;
      break;
    }

    if (lastFinished == null) {
      showAppFeedback(
        context,
        'No finished game with playable moves is available yet.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }

    _openRecordAnalysis(lastFinished, backTarget: 'Analysis');
  }

  Future<void> _continueRecord(GameRecord record) async {
    _activeLocalGameRecord = record.localRecordId.isEmpty
        ? null
        : await localGameRecordStore.find(record.localRecordId);
    if (!mounted) return;
    if (record.canContinueLichessGame) {
      await _continueLichessRecord(record);
      return;
    }
    if (record.canContinueOtbGame) {
      _continueOtbRecord(record);
      return;
    }
    _continueBotRecord(record);
  }

  void _continueOtbRecord(GameRecord record) {
    if (!record.canContinueOtbGame) return;
    setState(() {
      _activeLocalGameRecord = localGameRecordStore.peek(record.localRecordId);
      gameMode = GameLaunchMode.otb;
      activeGameRecordId = record.pgnId;
      activeGameShareId = record.shareId;
      otbGameConfig = _otbConfigFromRecord(record);
    });
    _go('Play');
  }

  void _continueBotRecord(GameRecord record) {
    if (!record.canContinueBotGame) return;
    setState(() {
      _activeLocalGameRecord = localGameRecordStore.peek(record.localRecordId);
      gameMode = GameLaunchMode.bot;
      activeGameRecordId = record.pgnId;
      activeGameShareId = record.shareId;
      botGameConfig = _botConfigFromRecord(record);
      _localContinueBotRecord = null;
    });
    _go('Play');
  }

  Future<void> _continueLichessRecord(GameRecord record) async {
    if (!record.canContinueLichessGame) return;
    String token = record.lichessToken;
    ApiResult<LichessTokenResult>? tokenResult;
    if (token.isEmpty) {
      tokenResult = await apiClient.getLichessToken();
      token = tokenResult.data?.token ?? '';
    }
    if (!mounted) return;
    if (token.isEmpty) {
      final expired = tokenResult != null &&
          isLichessAuthorizationExpiredStatus(tokenResult.status);
      showAppFeedback(
        context,
        expired
            ? 'Lichess authorization expired. Re-authorize before continuing.'
            : tokenResult?.status.errorMessage ??
                'Unable to check Lichess authorization. Please try again.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    final service = LichessBoardService(
      token: token,
      localLichessName: _currentLichessName(record),
      httpClient: apiClient.httpClient,
    );
    final snapshot = await service.checkGame(record.lichessGameId);
    if (!mounted) return;
    if (!snapshot.canContinue) {
      if (_isLichessSnapshotCheckFailure(snapshot)) {
        showAppFeedback(
          context,
          _lichessFailureMessage(
            'Unable to check Lichess authorization. Please try again.',
            snapshot.errorMessage ?? service.lastErrorMessage,
          ),
          tone: AppFeedbackTone.warning,
        );
        return;
      }
      _removeOngoingLichessGame(record.lichessGameId);
      if (record.pgnId != null) {
        await _finalizeInactiveLichessRecord(record, snapshot);
      }
      if (!mounted) return;
      showAppFeedback(
        context,
        'This Lichess game has ended: ${snapshot.resultToken}.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    setState(() {
      gameMode = GameLaunchMode.lichess;
      activeGameRecordId = record.pgnId;
      activeGameShareId = record.shareId;
      final currentLichessName = _currentLichessName(record);
      final localName = switch (snapshot.localSide) {
        LichessPlayerSide.black => snapshot.blackName?.trim() ?? '',
        LichessPlayerSide.white => snapshot.whiteName?.trim() ?? '',
        LichessPlayerSide.none => currentLichessName,
      };
      lichessGameConfig = LichessGameConfig(
        gameId: record.lichessGameId,
        token: token,
        // Player identity is taken from the official game snapshot.  Do not
        // pass the record page's cached names, clocks, or PGN into the room.
        lichessName: localName,
        timeMinutes: 0,
        incrementSeconds: 0,
        rated: snapshot.rated ?? false,
      );
    });
    _go('Play');
  }

  String _currentLichessName(GameRecord record) {
    final session = apiClient.session;
    if (session is ChessnutLoginSession) {
      final linkedName = session.lichessName.trim();
      if (linkedName.isNotEmpty) return linkedName;
    }
    return record.lichessName.trim();
  }

  Future<void> _finalizeInactiveLichessRecord(
    GameRecord record,
    LichessGameSnapshot snapshot, {
    bool reloadRecords = true,
  }) async {
    final result = snapshot.resultToken;
    final pgn = _pgnWithResult(record.pgn, result);
    final update = await apiClient.updatePgn(
      pgnId: record.pgnId ?? 0,
      pgn: pgn,
      whiteName: record.whiteName,
      blackName: record.blackName,
      winId: switch (result) {
        '1-0' => 1,
        '0-1' => 2,
        '1/2-1/2' => 3,
        _ => 0,
      },
      gameStatus: 2,
      gameStep: record.gameStep,
      metadata: PgnSaveMetadata(
        lichessGameId: record.lichessGameId,
        lichessToken: record.lichessToken,
        lichessName: record.lichessName,
        playerColor: record.playerColorOverride,
        speed: record.speedOverride,
        timeControl: record.timeControlOverride,
        opponentName: record.opponentNameOverride,
      ),
    );
    if (update.isSuccess && record.pgnId != null) {
      await gameRecordRepository.invalidateRecordPgn(record.pgnId!);
    }
    if (update.isSuccess && reloadRecords) {
      unawaited(_refreshWalletTaskState());
      await _loadGameRecords();
    }
  }

  String _pgnWithResult(String pgn, String result) {
    var next = pgn.replaceFirst(
      RegExp(r'^\[Result\s+".*"\]$', multiLine: true),
      '[Result "$result"]',
    );
    next = next.replaceFirst(RegExp(r'\s+\*$'), ' $result');
    return next;
  }

  Future<GameRecordRemoteSearchResult> _searchRemoteGameRecords(
      GameRecordFilter filter, int page, int count,
      {bool deferRemotePgn = true}) async {
    final result = await gameRecordRepository.searchRecords(
        _gameRecordSearchRequest(
          filter,
          page: page,
          count: count,
        ),
        deferRemotePgn: deferRemotePgn);
    if (!result.isSuccess) return result;
    if (filter.mode == RecordModeFilter.local &&
        result.records.any(
          (record) => _sourceTabForGameRecord(record) != RecordSourceTab.local,
        )) {
      return _searchLocalGameRecordsWithClientFallback(
        filter,
        page: page,
        count: count,
        status: result.status,
        deferRemotePgn: deferRemotePgn,
      );
    }
    return GameRecordRemoteSearchResult(
      status: result.status,
      records: _filterDeletedGameRecords(result.records),
      page: result.page,
      count: result.count,
      total: result.total,
      totalPage: result.totalPage,
      hydratedRecords: result.hydratedRecords,
    );
  }

  /// The Engine Lab needs the actual PGN immediately because it renders a
  /// position preview and sends the selected games for training. The regular
  /// Game Record page keeps using deferred PGN hydration for fast paging.
  Future<GameRecordRemoteSearchResult> _searchModelBuildGameRecords(
    GameRecordFilter filter,
    int page,
    int count,
  ) {
    return _searchRemoteGameRecords(
      filter,
      page,
      count,
      deferRemotePgn: false,
    );
  }

  Future<GameRecordRemoteSearchResult> _summarizeRemoteGameRecords(
    GameRecordFilter filter,
  ) async {
    final result = await apiClient.searchGameRecords(_gameRecordSearchRequest(
      filter,
      page: 1,
      count: 1,
    ));
    if (!result.isSuccess) {
      return GameRecordRemoteSearchResult(
        status: result.status,
        page: 1,
        count: 1,
      );
    }
    final data = result.data;
    final total = data?.total ?? 0;
    final totalPage = data?.totalPage ?? 0;
    final records = data?.records ?? const <PgnRecord>[];
    final matchCount = total > 0
        ? total
        : records.isEmpty
            ? 0
            : math.max(records.length, totalPage);
    return GameRecordRemoteSearchResult(
      status: const ApiStatus.success(),
      page: 1,
      count: 1,
      total: matchCount,
      totalPage: matchCount,
    );
  }

  Future<GameRecordRemoteSearchResult>
      _searchLocalGameRecordsWithClientFallback(
    GameRecordFilter filter, {
    required int page,
    required int count,
    required ApiStatus status,
    bool deferRemotePgn = true,
  }) async {
    const scanPageSize = 100;
    final targetEnd = page * count;
    final matches = <GameRecord>[];
    final seen = <String>{};
    var scanPage = 1;
    var totalPage = 1;
    while (scanPage <= totalPage &&
        scanPage <= 50 &&
        (matches.length < targetEnd || scanPage <= math.min(totalPage, 3))) {
      final result = await gameRecordRepository.searchRecords(
        _gameRecordSearchRequest(
          filter,
          page: scanPage,
          count: scanPageSize,
        ),
        deferRemotePgn: deferRemotePgn,
      );
      if (!result.isSuccess) return result;
      totalPage = math.max(1, result.totalPage);
      for (final record in _filterDeletedGameRecords(result.records)) {
        if (!_matchesLocalGameRecordFallback(record, filter)) continue;
        if (seen.add(_continueRecordKey(record))) {
          matches.add(record);
        }
      }
      if (result.records.isEmpty) break;
      scanPage += 1;
    }
    matches.sort((a, b) => _compareFallbackGameRecords(a, b, filter.sort));
    final start = ((page - 1) * count).clamp(0, matches.length).toInt();
    final end = math.min(matches.length, start + count);
    final visible = matches.sublist(start, end);
    final total = math.max(
        matches.length, _gameRecordSourceCounts?[RecordSourceTab.local] ?? 0);
    return GameRecordRemoteSearchResult(
      status: status,
      records: visible,
      page: page,
      count: count,
      total: total,
      totalPage: math.max(1, (total / count).ceil()),
    );
  }

  bool _matchesLocalGameRecordFallback(
    GameRecord record,
    GameRecordFilter filter,
  ) {
    if (_sourceTabForGameRecord(record) != RecordSourceTab.local) return false;
    if (!_matchesFallbackResult(record, filter.result)) return false;
    if (!_matchesFallbackColor(record, filter.color)) return false;
    if (filter.speed != RecordSpeedFilter.all &&
        record.speed != filter.speed.name) {
      return false;
    }
    if (filter.minMoves > 0 && record.fullMoveCount < filter.minMoves) {
      return false;
    }
    final query = filter.query.trim().toLowerCase();
    if (query.isEmpty) return true;
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
    return haystack.contains(query);
  }

  bool _matchesFallbackResult(GameRecord record, RecordResultFilter result) {
    final token = record.finishedResultToken;
    return switch (result) {
      RecordResultFilter.all => true,
      RecordResultFilter.win => _isFallbackPlayerWin(record),
      RecordResultFilter.loss => _isFallbackPlayerLoss(record),
      RecordResultFilter.draw => token == '1/2-1/2',
      RecordResultFilter.unfinished => token == '*',
    };
  }

  bool _matchesFallbackColor(GameRecord record, RecordColorFilter color) {
    final playerColor = _fallbackPlayerColorFor(record);
    return switch (color) {
      RecordColorFilter.all => true,
      RecordColorFilter.white => playerColor == 'white',
      RecordColorFilter.black => playerColor == 'black',
    };
  }

  bool _isFallbackPlayerWin(GameRecord record) {
    final token = record.finishedResultToken;
    return switch (_fallbackPlayerColorFor(record)) {
      'white' => token == '1-0',
      'black' => token == '0-1',
      _ => token == '1-0',
    };
  }

  bool _isFallbackPlayerLoss(GameRecord record) {
    final token = record.finishedResultToken;
    return switch (_fallbackPlayerColorFor(record)) {
      'white' => token == '0-1',
      'black' => token == '1-0',
      _ => token == '0-1',
    };
  }

  String _fallbackPlayerColorFor(GameRecord record) {
    final declared = record.declaredPlayerColor;
    if (declared.isNotEmpty) return declared;
    final session = apiClient.session;
    final names = <String>{
      if (session is ChessnutLoginSession) ...[
        session.username,
        session.email,
        session.email.split('@').first,
        session.lichessName,
        session.chessName,
        session.phone,
      ],
      record.lichessName,
    }
        .map(_normalizeFallbackPlayerName)
        .where((name) => name.isNotEmpty)
        .toSet();
    if (names.contains(_normalizeFallbackPlayerName(record.displayWhiteName))) {
      return 'white';
    }
    if (names.contains(_normalizeFallbackPlayerName(record.displayBlackName))) {
      return 'black';
    }
    return record.playerColor;
  }

  String _normalizeFallbackPlayerName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  int _compareFallbackGameRecords(
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
    final compared = (a.pgnId ?? 0).compareTo(b.pgnId ?? 0);
    return sortMode == RecordSortMode.oldest ? compared : -compared;
  }

  Future<ApiResult<ModelBuildGameRecordJob>> _startModelBuildGameRecordsPreview(
    GameRecordFilter filter,
    int limit,
  ) {
    return apiClient.startModelBuildGameRecordsPreview(
      request: _gameRecordSearchRequest(filter, page: 1, count: limit),
      limit: limit,
    );
  }

  Future<ApiResult<ModelBuildGameRecordJob>> _startModelBuildGameRecordsPush(
    GameRecordFilter filter,
    String title,
    String remark,
    int limit,
  ) {
    return apiClient.startModelBuildGameRecordsPush(
      request: _gameRecordSearchRequest(filter, page: 1, count: limit),
      title: title,
      remark: remark,
      limit: limit,
    );
  }

  Future<ApiResult<ModelBuildGameRecordJob>> _checkModelBuildGameRecordsJob(
    String jobId,
  ) {
    return apiClient.modelBuildGameRecordsStatus(jobId);
  }

  Future<ApiResult<ModelBuildGameRecordJob>> _cancelModelBuildGameRecordsJob(
    String jobId,
  ) {
    return apiClient.cancelModelBuildGameRecordsJob(jobId);
  }

  GameRecordSearchRequest _gameRecordSearchRequest(
    GameRecordFilter filter, {
    required int page,
    required int count,
  }) {
    return GameRecordSearchRequest(
      page: page,
      count: count,
      query: filter.query,
      mode: _remoteRecordMode(filter.mode),
      result: _remoteRecordResult(filter.result),
      speed: filter.speed == RecordSpeedFilter.all ? '' : filter.speed.name,
      color: filter.color == RecordColorFilter.all ? '' : filter.color.name,
      report: filter.report == RecordReportFilter.grandeur
          ? RecordReportFilter.grandeur.name
          : '',
      minMoves: filter.minMoves,
      sort: filter.sort.name,
    );
  }

  Future<List<String>> _fetchLichessHistoryGames(
    LichessHistoryImportOptions options,
  ) async {
    final page =
        await LichessPgnService(httpClient: apiClient.httpClient).fetchGames(
      options: LichessPgnFetchOptions(
        playerId: options.playerId,
        since: options.since,
        until: options.until,
        speed: options.speed,
        rated: options.rated,
        color: options.color,
      ),
      pageSize: options.maxGames.clamp(1, historyPgnBatchLimit),
    );
    return splitPgnGames(
      page.pgn,
      limit: options.maxGames.clamp(1, historyPgnBatchLimit),
    );
  }

  Future<List<String>> _fetchChessComHistoryGames(
    LichessHistoryImportOptions options,
  ) async {
    final result =
        await ChessComPgnService(httpClient: apiClient.httpClient).fetchGames(
      options: ChessComPgnFetchOptions(
        username: options.playerId,
        since: options.since,
        until: options.until,
      ),
      maxGames: options.maxGames.clamp(1, historyPgnBatchLimit),
    );
    return result.games;
  }

  Future<ApiResult<int>> _importHistoryPgnBatch(
    String pgnList,
    String source,
  ) {
    return apiClient.uploadPgnList(pgnList: pgnList, source: source);
  }

  String _remoteRecordMode(RecordModeFilter mode) {
    return switch (mode) {
      RecordModeFilter.all => '',
      RecordModeFilter.local => 'local',
      RecordModeFilter.bot => 'bot',
      RecordModeFilter.otb => 'otb',
      RecordModeFilter.lichess => 'lichess',
      RecordModeFilter.chesscom => 'chesscom',
    };
  }

  String _remoteRecordResult(RecordResultFilter result) {
    return switch (result) {
      RecordResultFilter.all => '',
      RecordResultFilter.win => 'win',
      RecordResultFilter.loss => 'loss',
      RecordResultFilter.draw => 'draw',
      RecordResultFilter.unfinished => 'unfinished',
    };
  }

  BotGameConfig _botConfigFromRecord(GameRecord record) {
    final headers = _pgnHeaders(record.pgn);
    final timeParts =
        (headers['TimeControl'] ?? '').split(RegExp(r'[+]')).toList();
    final minutes = timeParts.isNotEmpty ? int.tryParse(timeParts.first) : null;
    final increment = timeParts.length > 1 ? int.tryParse(timeParts[1]) : null;
    final white = record.whiteName.trim().isNotEmpty
        ? record.whiteName.trim()
        : headers['White'] ?? 'Chessnut Player';
    final black = record.blackName.trim().isNotEmpty
        ? record.blackName.trim()
        : headers['Black'] ?? 'Maia 1500';
    final playerSide = _botPlayerSideFromRecord(headers, white, black);
    final playerIsBlack = playerSide == BotPlayerSide.black;
    final opponent = playerIsBlack ? white : black;
    final careerMode = _careerModeFromRecordHeaders(headers);
    final engineKind = _botEngineKindFromHeader(headers['EngineKind']);
    final maiaElo = _intHeader(headers, 'MaiaElo') ??
        const BotGameConfig.defaultConfig().maiaElo;
    final stockfishElo = _intHeader(headers, 'StockfishElo') ??
        const BotGameConfig.defaultConfig().stockfishElo;
    final showPgnList = widget.isChessnutClockDevice
        ? headers['ShowPgnList']?.trim().toLowerCase() != 'false'
        : true;
    final title = careerMode == null
        ? '$opponent / ${minutes ?? 10}+${increment ?? 5}'
        : '$opponent / ELO $maiaElo';
    return const BotGameConfig.defaultConfig().copyWith(
      title: title,
      subtitle: careerMode == null
          ? const BotGameConfig.defaultConfig().subtitle
          : 'Career challenge / ${standardOpeningScenario.name}',
      opponent: opponent,
      opponentSource: careerMode == null
          ? const BotGameConfig.defaultConfig().opponentSource
          : 'Career resume / ELO $maiaElo',
      playerSide: playerSide,
      timeMinutes: minutes,
      incrementSeconds: increment,
      engineKind: engineKind,
      maiaElo: maiaElo,
      stockfishElo: stockfishElo,
      showPgnList: showPgnList,
      startFen: headers['FEN'],
      careerMode: careerMode,
      resumePgn: record.pgn,
    );
  }

  CareerModeConfig? _careerModeFromRecordHeaders(Map<String, String> headers) {
    final encoded = headers['CareerMode']?.trim();
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(base64Decode(encoded)));
        if (decoded is Map<String, dynamic>) {
          return CareerModeConfig.fromJson(decoded);
        }
        if (decoded is Map) {
          return CareerModeConfig.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (_) {
        // Fall through to legacy scalar headers.
      }
    }
    final mode = headers['GameMode']?.trim().toLowerCase();
    final event = headers['Event']?.trim().toLowerCase() ?? '';
    if (mode != 'career' && !event.contains('career challenge')) return null;
    final startElo = _intHeader(headers, 'CareerStartElo') ?? 1200;
    final progress = CareerModeProgress.fromElo(startElo);
    return CareerModeConfig(
      startElo: startElo.clamp(600, 3190).toInt(),
      winElo: (_intHeader(headers, 'CareerWinElo') ??
              progress.eloAfter(CareerGameOutcome.victory))
          .clamp(600, 3190)
          .toInt(),
      loseElo: (_intHeader(headers, 'CareerLoseElo') ??
              progress.eloAfter(CareerGameOutcome.defeat))
          .clamp(600, 3190)
          .toInt(),
      opponentName: headers['CareerOpponentName']?.trim().isNotEmpty == true
          ? headers['CareerOpponentName']!.trim()
          : 'Career opponent',
      opponentAvatarAsset: headers['CareerOpponentAvatar']?.trim() ?? '',
    );
  }

  int? _intHeader(Map<String, String> headers, String key) {
    return int.tryParse(headers[key]?.trim() ?? '');
  }

  BotEngineKind _botEngineKindFromHeader(String? value) {
    final name = value?.trim();
    if (name == null || name.isEmpty) {
      return const BotGameConfig.defaultConfig().engineKind;
    }
    for (final kind in BotEngineKind.values) {
      if (kind.name == name) return kind;
    }
    return const BotGameConfig.defaultConfig().engineKind;
  }

  BotPlayerSide _botPlayerSideFromRecord(
    Map<String, String> headers,
    String white,
    String black,
  ) {
    final playerSide = headers['PlayerSide']?.trim().toLowerCase();
    if (playerSide == 'black') return BotPlayerSide.black;
    if (playerSide == 'white') return BotPlayerSide.white;
    final localName = _currentChessnutPlayerName().toLowerCase();
    if (localName.isNotEmpty) {
      if (black.toLowerCase() == localName) return BotPlayerSide.black;
      if (white.toLowerCase() == localName) return BotPlayerSide.white;
    }
    if (black == 'Chessnut Player') return BotPlayerSide.black;
    return BotPlayerSide.white;
  }

  String _currentChessnutPlayerName() {
    final session = apiClient.session;
    if (session is ChessnutLoginSession) {
      final username = session.username.trim();
      if (username.isNotEmpty) return username;
      final emailName = session.email.split('@').first.trim();
      if (emailName.isNotEmpty) return emailName;
      final phone = session.phone.trim();
      if (phone.isNotEmpty) return phone;
    }
    return 'Chessnut Player';
  }

  OtbGameConfig _otbConfigFromRecord(GameRecord record) {
    final headers = _pgnHeaders(record.pgn);
    final timeParts =
        (headers['TimeControl'] ?? record.subtitle).split(RegExp(r'[+]'));
    final baseToken = timeParts.isNotEmpty ? timeParts.first.trim() : '';
    final baseValue = int.tryParse(baseToken);
    final minutes = baseValue == null
        ? null
        : baseValue > 60
            ? (baseValue / 60).round()
            : baseValue;
    final increment =
        timeParts.length > 1 ? int.tryParse(timeParts[1].trim()) : null;
    final startFen = headers['FEN']?.trim().isNotEmpty == true
        ? headers['FEN']!.trim()
        : chessnutStandardStartFen;
    final chess960 = headers['Variant']?.trim().toLowerCase() == 'chess960';
    final showPgnList = widget.isChessnutClockDevice
        ? headers['ShowPgnList']?.trim().toLowerCase() != 'false'
        : true;
    final knownOpening = botOpeningScenarios.where(
      (opening) => opening.fen == startFen,
    );
    final opening = knownOpening.isNotEmpty
        ? knownOpening.first
        : OpeningScenario(
            id: chess960 ? 'chess960-resume' : 'otb-resume-position',
            name: chess960 ? 'Chess960' : 'Saved position',
            eco: chess960 ? '960' : 'FEN',
            moves: 'Continued OTB game',
            fen: startFen,
            focus: 'Resume game',
          );
    return OtbGameConfig(
      timeMinutes: minutes ?? 10,
      incrementSeconds: increment ?? 5,
      opening: opening,
      startFen: startFen,
      chess960: chess960,
      showPgnList: showPgnList,
      resumePgn: record.pgn,
    );
  }

  Map<String, String> _pgnHeaders(String pgn) {
    final headers = <String, String>{};
    final pattern = RegExp(r'^\[([A-Za-z0-9_]+)\s+"(.*)"\]$');
    for (final line in pgn.split(RegExp(r'\r?\n'))) {
      final match = pattern.firstMatch(line.trim());
      if (match == null) continue;
      headers[match.group(1)!] =
          match.group(2)!.replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
    }
    return headers;
  }

  void _launchGame(
    GameLaunchMode mode, {
    BotGameConfig? botConfig,
    OtbGameConfig? otbConfig,
    LichessGameConfig? lichessConfig,
  }) {
    _activeLocalGameRecord = null;
    if (otbConfig != null) {
      otbGameConfig = otbConfig;
    }
    if (mode == GameLaunchMode.chesscom) {
      setState(() => chessComResumeUrl = null);
      _go('ChessCom');
      return;
    }
    if (mode == GameLaunchMode.clock) {
      _go('Clock');
      return;
    }
    setState(() {
      if (mode == GameLaunchMode.bot) {
        _returnHomeAfterPostGameBotSettings = false;
      }
      gameMode = mode;
      activeGameRecordId = null;
      activeGameShareId = null;
      if (botConfig != null) {
        botGameConfig = botConfig;
      }
      if (lichessConfig != null) {
        lichessGameConfig = lichessConfig;
      }
      if (mode == GameLaunchMode.bot) {
        _localContinueBotRecord = null;
      }
    });
    if (mode == GameLaunchMode.bot &&
        botConfig != null &&
        botConfig.careerMode == null) {
      unawaited(_persistLastBotGameConfig(botConfig));
    }
    _go('Play');
  }

  void _launchCareerGame(BotGameConfig config) {
    _careerRematchRequest = 0;
    _careerRematchExcludedOpponent = '';
    _launchGame(GameLaunchMode.bot, botConfig: config);
  }

  void _rematchCareerOpponent() {
    final previousOpponent = botGameConfig.careerMode?.opponentName ?? '';
    setState(() {
      _activeLocalGameRecord = null;
      activeGameRecordId = null;
      activeGameShareId = null;
      _careerRematchExcludedOpponent = previousOpponent;
      _careerRematchRequest += 1;
    });
    _go('Career');
  }

  void _connectBoard(
    PhysicalBoardModel model, {
    PhysicalBoardGateway? gateway,
  }) {
    final target = routes.indexWhere((route) => route.label == 'Home');
    if (target < 0) return;
    if (gateway != null) {
      _useBoardGateway(gateway);
    }
    if (boardGateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    _startShellBoardStateSync();
    _startShellBoardBatterySync();
    _startShellBoardFenIdleSync();
    unawaited(_applyBoardSettingsAfterConnect());
    _boardReconnectAttemptedForDisconnect = false;
    setState(() {
      boardConnected = true;
      connectedBoardModel = _appBoardModelFromPhysical(model);
      index = target;
      _recordRoute('Home', resetStack: true, replace: false);
    });
    unawaited(_clearPhysicalBoardLightsForHome());
    _syncBoardBackgroundKeepAlive();
    _syncHomeWidgetSnapshot();
    _syncWidgetVisionPlayService();
  }

  void _useBoardGateway(PhysicalBoardGateway gateway) {
    if (identical(boardGateway, gateway)) return;
    if (ownsBoardGateway && boardGateway is ChessnutBoardGateway) {
      unawaited((boardGateway as ChessnutBoardGateway).dispose());
    }
    unawaited(_shellBoardStateSub?.cancel());
    _shellBoardStateSub = null;
    _stopBoardFenIdleSync();
    boardGateway = gateway;
    _syncWidgetVisionPlayService();
  }

  void _syncBuiltInEvo2BoardGateway() {
    if (widget.boardGateway != null || !widget.isChessnutEvo2Device) return;
    if (boardGateway.boardModel == PhysicalBoardModel.evo2) {
      unawaited(_autoConnectBuiltInEvo2Board());
      return;
    }
    _useBoardGateway(
      ChessnutBoardGateway(transport: Evo2UsbBoardTransport()),
    );
    unawaited(_autoConnectBuiltInEvo2Board());
  }

  void _markBoardConnectedInPlace(PhysicalBoardModel model) {
    if (boardGateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    _startShellBoardStateSync();
    _startShellBoardBatterySync();
    _startShellBoardFenIdleSync();
    unawaited(_applyBoardSettingsAfterConnect());
    _boardReconnectAttemptedForDisconnect = false;
    setState(() {
      boardConnected = true;
      connectedBoardModel = _appBoardModelFromPhysical(model);
    });
    _syncBoardBackgroundKeepAlive();
    _syncHomeWidgetSnapshot();
    _syncWidgetVisionPlayService();
  }

  void _disconnectBoard() {
    final target = routes.indexWhere((route) => route.label == 'Home');
    if (target < 0) return;
    _disconnectBoardHardware();
    setState(() {
      boardConnected = false;
      connectedBoardModel = ChessnutBoardModel.unknown;
      boardBatteryStatus = null;
      index = target;
      _recordRoute('Home', resetStack: true, replace: false);
    });
    _syncBoardBackgroundKeepAlive();
    _syncHomeWidgetSnapshot();
    _syncWidgetVisionPlayService();
  }

  void _disconnectBoardHardware() {
    _syncBoardBackgroundKeepAlive(enabledOverride: false);
    unawaited(
        widget.boardBackgroundConnectionService.disconnectBoardHardware());
    unawaited(boardGateway.disconnect());
    unawaited(_shellBoardStateSub?.cancel());
    _shellBoardStateSub = null;
    _stopBoardFenIdleSync();
    _shellBoardBatteryTimer?.cancel();
    _shellBoardBatteryTimer = null;
    unawaited(_shellBoardBatterySub?.cancel());
    _shellBoardBatterySub = null;
  }

  void _disconnectBoardForAppShutdown() {
    _disconnectBoardHardware();
    boardConnected = false;
    connectedBoardModel = ChessnutBoardModel.unknown;
    boardBatteryStatus = null;
    _syncHomeWidgetSnapshot();
    _syncWidgetVisionPlayService();
  }

  void _handleBoardGatewayDisconnected() {
    if (!mounted || !boardConnected) return;
    final evo2PowerController = _evo2ScreenOffGameController;
    final evo2ScreenOffPowerDown = widget.isChessnutEvo2Device &&
        (evo2PowerController?.powerSuspended == true ||
            (_appLifecycleState != AppLifecycleState.resumed &&
                evo2PowerController?.enabled == false));
    if (evo2ScreenOffPowerDown) {
      _handleEvo2PoweredOffBoard();
      return;
    }
    if (routes[index].label == 'Play') {
      _handleGameBoardGatewayDisconnected();
      return;
    }
    final target = routes.indexWhere((route) => route.label == 'Home');
    if (target < 0) return;
    unawaited(_shellBoardStateSub?.cancel());
    _shellBoardStateSub = null;
    _stopBoardFenIdleSync();
    _shellBoardBatteryTimer?.cancel();
    _shellBoardBatteryTimer = null;
    unawaited(_shellBoardBatterySub?.cancel());
    _shellBoardBatterySub = null;
    setState(() {
      boardConnected = false;
      connectedBoardModel = ChessnutBoardModel.unknown;
      boardBatteryStatus = null;
      index = target;
      _recordRoute('Home', resetStack: true, replace: false);
    });
    unawaited(_clearPhysicalBoardLightsForHome());
    _syncBoardBackgroundKeepAlive();
    _syncHomeWidgetSnapshot();
  }

  void _handleEvo2PoweredOffBoard() {
    _stopBoardFenIdleSync();
    _shellBoardBatteryTimer?.cancel();
    _shellBoardBatteryTimer = null;
    unawaited(_shellBoardBatterySub?.cancel());
    _shellBoardBatterySub = null;
    setState(() {
      boardConnected = false;
      connectedBoardModel = ChessnutBoardModel.evo2;
      boardBatteryStatus = null;
    });
    _syncHomeWidgetSnapshot();
    _syncWidgetVisionPlayService();
  }

  Future<void> _clearPhysicalBoardLightsForHome() async {
    await _clearPhysicalBoardLightsOnce();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || routes[index].label != 'Home') return;
    await _clearPhysicalBoardLightsOnce();
  }

  Future<void> _clearPhysicalBoardLightsOnce({
    bool stopMoveBoard = true,
  }) async {
    final gateway = boardGateway;
    if (gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (gateway.boardModel == PhysicalBoardModel.move) {
      await gateway.clearMoveLeds();
      if (stopMoveBoard) {
        await gateway.stopMoveBoard();
      }
      return;
    }
    if (gateway.boardModel == PhysicalBoardModel.evo2) {
      await gateway.setEvo2LedPatternKeys(
        List<String?>.filled(64, null),
        boardSettings.evo2LedPatterns,
      );
      return;
    }
    if (gateway.boardModel.usesGeneralProtocol) {
      await gateway.clearGeneralLeds();
    }
  }

  void _handleGameBoardGatewayDisconnected() {
    _stopBoardFenIdleSync();
    _shellBoardBatteryTimer?.cancel();
    _shellBoardBatteryTimer = null;
    unawaited(_shellBoardBatterySub?.cancel());
    _shellBoardBatterySub = null;
    setState(() {
      boardConnected = false;
      connectedBoardModel = ChessnutBoardModel.unknown;
      boardBatteryStatus = null;
    });
    _syncBoardBackgroundKeepAlive();
    _syncHomeWidgetSnapshot();
    if (!_boardReconnectInFlight && !_boardReconnectAttemptedForDisconnect) {
      _boardReconnectAttemptedForDisconnect = true;
      unawaited(_reconnectBoardDuringGame());
    }
  }

  Future<void> _reconnectBoardDuringGame() async {
    if (_boardReconnectInFlight) return;
    _boardReconnectInFlight = true;
    final gateway = boardGateway;
    var reconnected = false;
    try {
      reconnected = await gateway.connect();
    } catch (_) {
      reconnected = false;
    } finally {
      if (mounted && identical(gateway, boardGateway)) {
        _boardReconnectInFlight = false;
      }
    }
    if (!mounted || !identical(gateway, boardGateway)) {
      return;
    }
    if (reconnected ||
        gateway.currentState == PhysicalBoardConnectionState.connected) {
      _startShellBoardBatterySync();
      _startShellBoardFenIdleSync();
      unawaited(_applyBoardSettingsAfterConnect());
      setState(() {
        boardConnected = true;
        connectedBoardModel = _appBoardModelFromPhysical(gateway.boardModel);
      });
      _boardReconnectAttemptedForDisconnect = false;
      _syncBoardBackgroundKeepAlive();
      _syncHomeWidgetSnapshot();
      return;
    }
    if (routes[index].label == 'Play') {
      showAppFeedback(
        context,
        'Board disconnected. Reconnect failed; the game will stay open.',
        tone: AppFeedbackTone.warning,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _autoConnectBuiltInEvo2Board() async {
    if (_builtInBoardAutoConnectInFlight ||
        !widget.isChessnutEvo2Device ||
        (boardConnected &&
            boardGateway.currentState ==
                PhysicalBoardConnectionState.connected)) {
      return;
    }
    _builtInBoardAutoConnectInFlight = true;
    final gateway = boardGateway;
    _startShellBoardStateSync();
    var connected = false;
    try {
      connected = await gateway.connect();
    } catch (_) {
      connected = false;
    } finally {
      if (mounted && identical(gateway, boardGateway)) {
        _builtInBoardAutoConnectInFlight = false;
      }
    }
    if (!mounted || !identical(gateway, boardGateway)) return;
    if (!connected &&
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    _startShellBoardBatterySync();
    _startShellBoardFenIdleSync();
    unawaited(_applyBoardSettingsAfterConnect());
    setState(() {
      boardConnected = true;
      connectedBoardModel = _appBoardModelFromPhysical(gateway.boardModel);
      boardBatteryStatus = null;
    });
    unawaited(_clearPhysicalBoardLightsForHome());
    _syncBoardBackgroundKeepAlive();
    _syncHomeWidgetSnapshot();
    _syncWidgetVisionPlayService();
  }

  void _updateKeepBoardConnectedInBackground(bool enabled) {
    widget.onKeepBoardConnectedInBackgroundChanged(enabled);
    unawaited(_evo2ScreenOffGameController?.setEnabled(enabled));
    _syncBoardBackgroundKeepAlive();
  }

  void _updateScreenOffGameActive(bool active) {
    _reportedScreenOffGameActive = active;
    _syncScreenOffGameActiveForCurrentRoute();
    _syncBoardBackgroundKeepAlive();
  }

  void _scheduleScreenOffGameActiveForRoute(String label) {
    if (_lastScreenOffGameRouteLabel == label) {
      return;
    }
    _lastScreenOffGameRouteLabel = label;
    if (label == 'Play' || label == 'ChessCom') {
      _reportedScreenOffGameActive = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || routes[index].label != label) return;
      _syncScreenOffGameActiveForCurrentRoute();
    });
  }

  void _syncScreenOffGameActiveForCurrentRoute() {
    unawaited(
      _evo2ScreenOffGameController?.setGameActive(
        _isScreenOffGameActiveForCurrentRoute,
      ),
    );
  }

  bool get _isScreenOffGameActiveForCurrentRoute {
    final label = routes[index].label;
    return (label == 'Play' || label == 'ChessCom') &&
        _reportedScreenOffGameActive;
  }

  void _handleScreenWakeIdleTimeout() {
    if (!widget.isChessnutEvo2Device) return;
    _evo2ScreenOffGameController?.handleDisplayIdleTimeout();
  }

  void _syncEvo2ScreenOffGameController() {
    if (!widget.isChessnutEvo2Device) {
      unawaited(_evo2ScreenOffGameController?.dispose());
      _evo2ScreenOffGameController = null;
      return;
    }
    final existing = _evo2ScreenOffGameController;
    if (existing != null) {
      unawaited(existing.setEnabled(widget.keepBoardConnectedInBackground));
      return;
    }
    final controller = Evo2ScreenOffGameController(
      powerService: widget.evo2UsbPowerService,
      clearLeds: () => _clearPhysicalBoardLightsOnce(stopMoveBoard: false),
      onPowerSuspendedChanged: (suspended) {
        if (suspended) {
          _syncBoardBackgroundKeepAlive(enabledOverride: false);
        } else {
          _syncBoardBackgroundKeepAlive();
        }
      },
      onPowerRestored: _restoreEvo2BoardAfterScreenUnlock,
      onGameLedsShouldRefresh: _requestEvo2GameLedRefresh,
    );
    _evo2ScreenOffGameController = controller;
    unawaited(() async {
      await controller.setEnabled(widget.keepBoardConnectedInBackground);
      await controller.start();
    }());
  }

  Future<void> _restoreEvo2BoardAfterScreenUnlock() async {
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted ||
        _evo2ScreenOffGameController?.screenOff == true ||
        !widget.isChessnutEvo2Device) {
      return;
    }
    await _autoConnectBuiltInEvo2Board();
    if (!mounted) return;
    _syncBoardBackgroundKeepAlive();
    if (_evo2ScreenOffGameController?.gameActive == true) {
      await _requestEvo2GameLedRefresh();
    }
  }

  Future<void> _requestEvo2GameLedRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || !widget.isChessnutEvo2Device) return;
    final label = routes[index].label;
    if (label != 'Play' && label != 'ChessCom') return;
    setState(() => _evo2LedRefreshRequestId += 1);
  }

  void _syncBoardBackgroundKeepAlive({bool? enabledOverride}) {
    final keepAliveEnabled =
        enabledOverride ?? (widgetVisionEnabled || boardConnected);
    unawaited(widget.boardBackgroundConnectionService.setKeepAlive(
      enabled: keepAliveEnabled,
      connected: boardConnected,
      boardModel: connectedBoardModel,
    ));
  }

  bool get _isAppInBackground =>
      _appLifecycleState == AppLifecycleState.hidden ||
      _appLifecycleState == AppLifecycleState.paused;

  bool get _screenOffBoardInteractionEnabled =>
      (!_isAppInBackground && !_windowsDisplayOff) ||
      widget.keepBoardConnectedInBackground;

  void _syncWindowsDisplayPower() {
    if (!widget.windowsDisplayPowerService.isSupported) return;
    unawaited(() async {
      _setWindowsDisplayOff(
        await widget.windowsDisplayPowerService.isDisplayOff(),
      );
    }());
    _windowsDisplayPowerSub =
        widget.windowsDisplayPowerService.displayOffChanges.listen(
      _setWindowsDisplayOff,
      onError: (_) {},
    );
  }

  void _setWindowsDisplayOff(bool displayOff) {
    if (!mounted || _windowsDisplayOff == displayOff) return;
    setState(() => _windowsDisplayOff = displayOff);
    if (displayOff && !widget.keepBoardConnectedInBackground) {
      unawaited(_clearPhysicalBoardLightsOnce(stopMoveBoard: false));
    }
  }

  void _startShellBoardFenIdleSync() {
    unawaited(_shellBoardFenSub?.cancel());
    _shellBoardFenSub = boardGateway.boardFenStream.listen(
      _handleKeepAliveBoardFen,
    );
    _lastKeepAliveBoardFen = null;
    final latestFen = boardGateway.latestBoardFen;
    if (latestFen != null && latestFen.trim().isNotEmpty) {
      _handleKeepAliveBoardFen(latestFen);
    }
  }

  void _handleKeepAliveBoardFen(String fen) {
    final boardOnlyFen = fen.trim().split(RegExp(r'\s+')).first;
    if (boardOnlyFen.isEmpty || boardOnlyFen == _lastKeepAliveBoardFen) {
      return;
    }
    _lastKeepAliveBoardFen = boardOnlyFen;
    _evo2ScreenOffGameController?.handleBoardFen(boardOnlyFen);
    _screenWakeFenActivityId += 1;
    if (mounted && shouldKeepScreenAwakeForRoute(routes[index].label)) {
      setState(() {});
    }
  }

  void _stopBoardFenIdleSync() {
    unawaited(_shellBoardFenSub?.cancel());
    _shellBoardFenSub = null;
    _lastKeepAliveBoardFen = null;
  }

  void _updateBoardSettings(BoardSettingsState settings) {
    final shouldClearPiecePositionLeds =
        boardSettings.piecePositionLed && !settings.piecePositionLed;
    final brightnessChanged =
        boardSettings.evo2LedBrightness != settings.evo2LedBrightness;
    setState(() => boardSettings = settings);
    unawaited(const SharedPreferencesBoardSettingsStore().write(settings));
    if (shouldClearPiecePositionLeds) {
      unawaited(_clearPhysicalBoardLightsOnce(stopMoveBoard: false));
    }
    if (brightnessChanged && widget.isChessnutEvo2Device) {
      unawaited(
        boardGateway.setEvo2LedBrightness(settings.evo2LedBrightness),
      );
    }
  }

  Future<void> _loadHomeWidgetState() async {
    final generation = ++_visionStateGeneration;
    final nativeVision =
        await widget.androidHomeWidgetService.readVisionEnabled();
    if (!mounted || generation != _visionStateGeneration) return;
    final savedVision = AppSharedPreferences.get<bool>(
      AppSettingKeys.widgetVisionEnabled,
    );
    final requested = nativeVision ?? savedVision;
    final nextVision = requested && await _visionAccessibilityAvailable();
    if (!mounted || generation != _visionStateGeneration) return;
    await _applyHomeWidgetVisionEnabled(nextVision);
    if (!mounted || generation != _visionStateGeneration) return;
    await _consumeHomeWidgetLaunchAction();
  }

  Future<bool> _visionAccessibilityAvailable() async {
    try {
      return await const AndroidAccessibilityVisionService()
          .isAccessibilityRunning()
          .timeout(const Duration(seconds: 1), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  void _syncHomeWidgetSnapshot() {
    final snapshot = ChessnutHomeWidgetSnapshot.fromAppState(
      boardConnected: boardConnected,
      boardModel: connectedBoardModel,
      boardBatteryStatus: boardBatteryStatus,
      continueRecord: _activeContinueRecord,
      visionEnabled: widgetVisionEnabled,
    );
    unawaited(widget.androidHomeWidgetService.syncSnapshot(snapshot));
  }

  Future<void> _setHomeWidgetVisionEnabled(bool enabled) async {
    final generation = ++_visionStateGeneration;
    final next = enabled && await _visionAccessibilityAvailable();
    if (!mounted || generation != _visionStateGeneration) return;
    await _applyHomeWidgetVisionEnabled(next);
  }

  Future<void> _applyHomeWidgetVisionEnabled(bool enabled) async {
    final changed = widgetVisionEnabled != enabled;
    if (changed) setState(() => widgetVisionEnabled = enabled);
    if (AppSharedPreferences.get<bool>(AppSettingKeys.widgetVisionEnabled) !=
        enabled) {
      AppSharedPreferences.set(AppSettingKeys.widgetVisionEnabled, enabled);
    }
    _syncHomeWidgetSnapshot();
    _syncWidgetVisionPlayService();
    if (changed) _syncBoardBackgroundKeepAlive();
    await widget.androidHomeWidgetService.setVisionEnabled(enabled);
  }

  void _setVisionRecognitionOnly(bool enabled) {
    if (visionRecognitionOnly == enabled) return;
    setState(() => visionRecognitionOnly = enabled);
    AppSharedPreferences.set(
      AppSettingKeys.visionRecognitionOnly,
      enabled,
    );
    _syncWidgetVisionPlayService();
  }

  void _syncWidgetVisionPlayService() {
    final routeAllowsVision = routes[index].label != 'Courses';
    widgetVisionPlayService.update(
      enabled: widgetVisionEnabled && routeAllowsVision,
      boardConnected: boardConnected,
      lifecycleState: _appLifecycleState,
      recognitionOnly: visionRecognitionOnly,
      languageTag: widget.languagePreference.tag,
    );
  }

  bool get _shouldPollBackgroundHomeWidget =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _appLifecycleState != AppLifecycleState.resumed &&
      (boardConnected || widgetVisionEnabled);

  void _syncBackgroundHomeWidgetPolling() {
    if (!_shouldPollBackgroundHomeWidget) {
      _backgroundHomeWidgetPollTimer?.cancel();
      _backgroundHomeWidgetPollTimer = null;
      return;
    }
    _backgroundHomeWidgetPollTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!_shouldPollBackgroundHomeWidget) {
          _syncBackgroundHomeWidgetPolling();
          return;
        }
        if (_homeWidgetActionInFlight) return;
        unawaited(_loadHomeWidgetState());
      },
    );
  }

  Future<void> _consumeHomeWidgetLaunchAction() async {
    if (_homeWidgetActionInFlight) return;
    _homeWidgetActionInFlight = true;
    try {
      final action =
          await widget.androidHomeWidgetService.consumeLaunchAction();
      if (!mounted || action == null) return;
      _pendingHomeWidgetAction = action;
      await _applyPendingHomeWidgetAction();
    } finally {
      _homeWidgetActionInFlight = false;
    }
  }

  Future<void> _applyPendingHomeWidgetAction() async {
    final action = _pendingHomeWidgetAction;
    if (action == null || routes[index].label == 'Splash') return;

    if (action.visionEnabled != null) {
      await _setHomeWidgetVisionEnabled(action.visionEnabled!);
    }

    switch (action.action) {
      case ChessnutHomeWidgetAction.toggleVision:
        _pendingHomeWidgetAction = null;
        return;
      case ChessnutHomeWidgetAction.connectBoard:
        _pendingHomeWidgetAction = null;
        _go(widget.isChessnutEvo2Device ? 'Home' : 'ConnectBoard');
        return;
      case ChessnutHomeWidgetAction.boardSettings:
        _pendingHomeWidgetAction = null;
        _go(widget.isChessnutEvo2Device || boardConnected
            ? 'BoardSettings'
            : 'ConnectBoard');
        return;
      case ChessnutHomeWidgetAction.records:
        _pendingHomeWidgetAction = null;
        _go('Records');
        return;
      case ChessnutHomeWidgetAction.playNow:
        _pendingHomeWidgetAction = null;
        _go('Setup');
        return;
      case ChessnutHomeWidgetAction.continueGame:
        final record = _activeContinueRecord;
        if (record == null) return;
        _pendingHomeWidgetAction = null;
        await _continueRecord(record);
        return;
      case ChessnutHomeWidgetAction.openApp:
        _pendingHomeWidgetAction = null;
        if (routes[index].label == 'Auth') return;
        _go('Home');
        return;
    }
  }

  void _updateBoardEditorFen(String fen) {
    setState(() => boardEditorFen = fen);
  }

  void _startBotGameFromEditorFen(String fen) {
    setState(() {
      boardEditorFen = fen;
      boardEditorBotRequestId += 1;
    });
    _go('Bot');
  }

  void _openBoardAnalyzerFromEditorFen(String fen) {
    setState(() => boardAnalyzerInitialFen = fen);
    _go('BoardAnalyzer');
  }

  Future<void> _loadBoardSettings() async {
    final settings = await const SharedPreferencesBoardSettingsStore().read();
    if (!mounted) return;
    setState(() => boardSettings = settings);
    if (widget.isChessnutEvo2Device &&
        boardGateway.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(
        boardGateway.setEvo2LedBrightness(settings.evo2LedBrightness),
      );
    }
  }

  Future<void> _applyBoardSettingsAfterConnect() async {
    if (boardGateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (boardGateway.boardModel == PhysicalBoardModel.evo2) {
      await boardGateway.setEvo2LedBrightness(boardSettings.evo2LedBrightness);
    }
    await boardGateway.setBoardBeepEnabled(boardSettings.globalBeep);
    if (boardSettings.effectiveConnectBeep) {
      await boardGateway.playBeep();
    }
  }

  void _startShellBoardStateSync() {
    unawaited(_shellBoardStateSub?.cancel());
    _shellBoardStateSub = boardGateway.stateStream.listen((state) {
      switch (state) {
        case PhysicalBoardConnectionState.connected:
          _boardReconnectAttemptedForDisconnect = false;
        case PhysicalBoardConnectionState.disconnected:
          _handleBoardGatewayDisconnected();
        case PhysicalBoardConnectionState.scanning ||
              PhysicalBoardConnectionState.connecting:
          break;
      }
    });
  }

  void _startShellBoardBatterySync() {
    unawaited(_shellBoardBatterySub?.cancel());
    _shellBoardBatteryTimer?.cancel();
    _shellBoardBatteryTimer = null;
    _shellBoardBatterySub = boardGateway.boardBatteryStatusStream.listen(
      (battery) {
        if (!mounted) return;
        setState(() => boardBatteryStatus = battery);
        _syncHomeWidgetSnapshot();
      },
    );
    unawaited(boardGateway.queryBoardBatteryStatus());
    _shellBoardBatteryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(boardGateway.queryBoardBatteryStatus()),
    );
  }

  @override
  void initState() {
    super.initState();
    visionRecognitionOnly = AppSharedPreferences.get<bool>(
      AppSettingKeys.visionRecognitionOnly,
    );
    WidgetsBinding.instance.addObserver(this);
    apiClient = ChessnutApiClient(
      httpClient: widget.httpClient,
      language: widget.apiLanguage,
      grandeurLanguage: widget.languagePreference.commentaryLanguage(
        WidgetsBinding.instance.platformDispatcher.locale,
      ),
      baseUri: ChessnutEndpointConfig.apiBaseUri,
      puzzleBaseUri: ChessnutEndpointConfig.puzzleBaseUri,
      moveUpdateUri: ChessnutEndpointConfig.moveUpdateUri,
      onSessionRefreshed: _handleSessionRefreshed,
      onAuthExpired: _handleAuthSessionExpired,
      onAuthTokenRefreshed: _showAuthTokenRefreshed,
      onNetworkError: _showNetworkConnectionError,
    );
    appUpdateService = AppUpdateService(
      apiClient: apiClient,
      packageNameProvider: () => ChessnutEndpointConfig.androidPackageName,
    );
    gameRecordRepository = GameRecordRepository(apiClient: apiClient);
    localGameRecordStore =
        widget.localGameRecordStore ?? LocalGameRecordStore();
    gameRecordSaveService = GameRecordSaveService(
      apiClient: apiClient,
      localStore: localGameRecordStore,
    );
    localGameRecordStore.addListener(_reloadLocalGameRecords);
    unawaited(_reloadLocalGameRecords());
    sessionStore = widget.sessionStore ?? const SecureChessnutSessionStore();
    credentialStore =
        widget.credentialStore ?? const SecureLoginCredentialStore();
    accountSwitcherStore = const SecureAccountSwitcherStore();
    appPreferencesStore =
        widget.appPreferencesStore ?? const FileAppPreferencesStore();
    analysisReportCacheStore =
        AppPreferencesAnalysisReportCacheStore(appPreferencesStore);
    mistakeBookStore = AppPreferencesMistakeBookStore(appPreferencesStore);
    lc0WeightLibraryStore = widget.lc0WeightLibraryStore ??
        AppPreferencesLc0WeightLibraryStore(
          preferencesStore: appPreferencesStore,
          httpClient: widget.httpClient,
        );
    unawaited(_loadBoardSettings());
    unawaited(_loadDismissedContinueRecordKeys());
    _appUpdateReminderLoadFuture = _loadAppUpdateReminder();
    unawaited(_appUpdateReminderLoadFuture);
    unawaited(_loadModuleGuideSeenIds());
    unawaited(_loadAnalysisReportStatuses());
    unawaited(_syncMistakeBookFromReports());
    unawaited(_loadLastBotGameConfig());
    reviewPromptService = widget.reviewPromptService ??
        ReviewPromptService(
          store: const SharedPreferencesReviewPromptStore(),
          requester: InAppReviewRequester(),
          appVersion: _reviewPromptAppVersion,
        );
    clockSwitchService = widget.clockSwitchService ??
        ChessClockSwitchService(
          enableUsbButtons: widget.isChessnutClockDevice,
        );
    clockSwitchService.initialize();
    ownsBoardGateway = widget.boardGateway == null;
    boardGateway = widget.boardGateway ??
        ChessnutBoardGateway(
          transport: widget.isChessnutEvo2Device
              ? Evo2UsbBoardTransport()
              : UniversalBleBoardTransport(),
        );
    widgetVisionPlayService = WidgetVisionPlayService(
      boardGatewayProvider: () => boardGateway,
      boardSettingsProvider: () => boardSettings,
    );
    _syncWindowsDisplayPower();
    _syncEvo2ScreenOffGameController();
    unawaited(_loadHomeWidgetState());
    final initialScreen =
        widget.initialScreen ?? Uri.base.queryParameters['screen'];
    if (initialScreen != null) {
      final target = routes.indexWhere(
        (route) => route.label.toLowerCase() == initialScreen.toLowerCase(),
      );
      if (target >= 0) index = target;
    } else if (_routeStack.isNotEmpty) {
      // Set index based on initial route stack
      final initialRoute = _routeStack.first;
      final target = routes.indexWhere((route) => route.label == initialRoute);
      if (target >= 0) index = target;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForAppUpdate(manual: false));
      _syncBuiltInEvo2BoardGateway();
      _maybeShowCurrentRouteGuide();
    });
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apiLanguage != oldWidget.apiLanguage) {
      apiClient.language.value = widget.apiLanguage;
    }
    if (widget.languagePreference != oldWidget.languagePreference) {
      apiClient.grandeurLanguage.value =
          widget.languagePreference.commentaryLanguage(
        WidgetsBinding.instance.platformDispatcher.locale,
      );
      _syncWidgetVisionPlayService();
    }
    if (widget.keepBoardConnectedInBackground !=
        oldWidget.keepBoardConnectedInBackground) {
      _syncBoardBackgroundKeepAlive();
      unawaited(_evo2ScreenOffGameController
          ?.setEnabled(widget.keepBoardConnectedInBackground));
    }
    if (widget.isChessnutClockDevice && !oldWidget.isChessnutClockDevice) {
      clockSwitchService.enableUsbButtons();
    }
    if (widget.isChessnutEvo2Device && !oldWidget.isChessnutEvo2Device) {
      _syncEvo2ScreenOffGameController();
      _syncBuiltInEvo2BoardGateway();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.detached) {
      _backgroundHomeWidgetPollTimer?.cancel();
      _backgroundHomeWidgetPollTimer = null;
      _disconnectBoardForAppShutdown();
      return;
    }
    _syncBackgroundHomeWidgetPolling();
    _syncWidgetVisionPlayService();
    _syncBoardBackgroundKeepAlive();
    if (state == AppLifecycleState.resumed) {
      if (widget.isChessnutEvo2Device) {
        unawaited(_evo2ScreenOffGameController?.restoreOnAppResume());
      } else {
        _syncBuiltInEvo2BoardGateway();
      }
      unawaited(_loadHomeWidgetState());
      unawaited(_checkForAppUpdate(manual: false));
      unawaited(_refreshOngoingLichessGames());
      unawaited(_refreshWalletTaskState());
    } else if (_isAppInBackground) {
      if (!widget.keepBoardConnectedInBackground ||
          !_isScreenOffGameActiveForCurrentRoute) {
        unawaited(_clearPhysicalBoardLightsOnce(stopMoveBoard: false));
      }
      unawaited(_loadHomeWidgetState());
    }
  }

  Future<void> _checkForAppUpdate({
    required bool manual,
  }) async {
    if (_appUpdateCheckInFlight) return;
    if (!manual && _appUpdateDismissedForProcess) return;
    if (!manual && _startupAppUpdateChecked) return;
    _appUpdateCheckInFlight = true;
    if (!manual) {
      _startupAppUpdateChecked = true;
    }
    try {
      await _ensureAppUpdateReminderLoaded();
      if (!mounted) return;
      if (AppUpdateService.currentPlatformName().toLowerCase() == 'android') {
        final playAvailability =
            await playInAppUpdateService.checkAvailability();
        if (!mounted) return;
        if (playAvailability.checkFailed) {
          if (manual) {
            showAppFeedback(
              context,
              AppStrings.of(context).t(
                'Could not check for updates. Please try again later.',
              ),
              tone: AppFeedbackTone.warning,
            );
          }
          return;
        }
        if (playAvailability.canStart &&
            (manual || playAvailability.immediateAllowed)) {
          final installed = await AppUpdateService.readInstalledVersion();
          if (!mounted) return;
          final latestVersionKey =
              _playUpdateVersionKey(playAvailability, installed);
          if (!manual &&
              _appUpdateReminder.shouldSuppress(
                latestVersionKey,
                DateTime.now(),
              )) {
            return;
          }
          final strings = AppStrings.of(context);
          final decision = AppUpdateDecision(
            hasUpdate: true,
            forceUpdate: playAvailability.immediateAllowed &&
                !playAvailability.flexibleAllowed,
            currentVersion: installed.fullVersion,
            latestVersion: playAvailability.availableVersionCode == null
                ? strings.t('Latest version')
                : 'build ${playAvailability.availableVersionCode}',
            downloadUrl: AppUpdateService.googlePlayUrlForPackage(
              ChessnutEndpointConfig.androidPackageName,
            ),
            releaseNotes: '',
            updateMethod: 'play_in_app',
            platformName: 'android',
            preferImmediatePlayUpdate: playAvailability.immediateAllowed,
          );
          final result = await showAppUpdateDialog(
            context,
            decision,
            showReminderChoices: !manual && !decision.forceUpdate,
            showLaterAction: manual,
            allowFlexiblePlayFallback: manual,
          );
          await _handleAppUpdateDialogResult(
            result,
            decision,
            latestVersionKey,
            manual: manual,
          );
          return;
        }
        if (manual) {
          final message = !playAvailability.installedFromGooglePlay
              ? 'Install Chessnut Next from Google Play to use in-app updates.'
              : playAvailability.available
                  ? 'Google Play update is not available right now.'
                  : 'You are using the latest version.';
          showAppFeedback(
            context,
            AppStrings.of(context).t(message),
            tone: playAvailability.available ||
                    !playAvailability.installedFromGooglePlay
                ? AppFeedbackTone.warning
                : AppFeedbackTone.success,
          );
        }
        return;
      }
      final decision = await appUpdateService.checkForUpdate();
      if (!mounted) return;
      if (decision?.hasUpdate == true) {
        final latestVersionKey = _appUpdateVersionKey(decision!);
        if (!manual &&
            _appUpdateReminder.shouldSuppress(
              latestVersionKey,
              DateTime.now(),
            )) {
          return;
        }
        final result = await showAppUpdateDialog(
          context,
          decision,
          showReminderChoices: !manual && !decision.forceUpdate,
          showLaterAction: manual,
          allowFlexiblePlayFallback: manual,
        );
        await _handleAppUpdateDialogResult(
          result,
          decision,
          latestVersionKey,
          manual: manual,
        );
        return;
      }
      if (manual) {
        showAppFeedback(
          context,
          AppStrings.of(context).t('You are using the latest version.'),
          tone: AppFeedbackTone.success,
        );
      }
    } catch (_) {
      if (manual && mounted) {
        showAppFeedback(
          context,
          AppStrings.of(context).t(
            'Could not check for updates. Please try again later.',
          ),
          tone: AppFeedbackTone.warning,
        );
      }
    } finally {
      _appUpdateCheckInFlight = false;
    }
  }

  String _playUpdateVersionKey(
    PlayInAppUpdateAvailability availability,
    AppInstalledVersion installed,
  ) {
    final versionCode = availability.availableVersionCode;
    if (versionCode != null && versionCode > 0) {
      return 'android-play:$versionCode';
    }
    return 'android-play:${installed.fullVersion}';
  }

  String _appUpdateVersionKey(AppUpdateDecision decision) {
    return '${decision.platformName}:${decision.updateMethod}:'
        '${decision.latestVersion}';
  }

  Future<void> _handleAppUpdateDialogResult(
    AppUpdateDialogResult? result,
    AppUpdateDecision decision,
    String latestVersionKey, {
    required bool manual,
  }) async {
    if (manual || decision.forceUpdate) return;
    switch (result) {
      case AppUpdateDialogResult.remindTomorrow:
        await _persistAppUpdateReminder(
          _appUpdateReminder.copyWith(
            deferredVersion: latestVersionKey,
            deferredUntil: DateTime.now().add(const Duration(days: 1)),
            ignoredVersion: '',
          ),
        );
        return;
      case AppUpdateDialogResult.ignoreVersion:
        await _persistAppUpdateReminder(
          _appUpdateReminder.copyWith(
            deferredVersion: '',
            clearDeferredUntil: true,
            ignoredVersion: latestVersionKey,
          ),
        );
        return;
      case AppUpdateDialogResult.later:
        _appUpdateDismissedForProcess = true;
        return;
      case AppUpdateDialogResult.opened:
      case null:
        break;
    }
  }

  Future<void> _closeLocalGameStore() async {
    try {
      await gameRecordSaveService.finishPendingSaves();
      await localGameRecordStore.close();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    localGameRecordStore.removeListener(_reloadLocalGameRecords);
    if (widget.localGameRecordStore == null) {
      unawaited(_closeLocalGameStore());
    }
    _disconnectBoardForAppShutdown();
    if (ownsBoardGateway && boardGateway is ChessnutBoardGateway) {
      unawaited((boardGateway as ChessnutBoardGateway).dispose());
    }
    if (ownsUsbBoardGateway && usbBoardGateway is EasyLinkBoardGateway) {
      unawaited((usbBoardGateway as EasyLinkBoardGateway).dispose());
    }
    _shellBoardBatteryTimer?.cancel();
    _backgroundHomeWidgetPollTimer?.cancel();
    unawaited(_shellBoardStateSub?.cancel());
    unawaited(_shellBoardBatterySub?.cancel());
    unawaited(_windowsDisplayPowerSub?.cancel());
    unawaited(clockSwitchService.dispose());
    unawaited(widgetVisionPlayService.dispose());
    unawaited(_evo2ScreenOffGameController?.dispose());
    unawaited(widget.boardBackgroundConnectionService.setKeepAlive(
      enabled: false,
      connected: false,
      boardModel: connectedBoardModel,
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = routes[index];
    final moveAndroidHomeToBackground = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        route.label == 'Home';
    _scheduleScreenOffGameActiveForRoute(route.label);
    final size = MediaQuery.sizeOf(context);
    final keepBoardEditorBackgroundStable = const {
      'Editor',
      'Setup',
      'Bot',
      'OtbSetup',
    }.contains(route.label);
    final keepKeyboardFromResizingBody =
        (route.label == 'Analysis' && isCompactLandscapeDevice(context)) ||
            keepBoardEditorBackgroundStable ||
            (widget.isChessnutClockDevice && route.label == 'Play') ||
            (widget.isChessnutEvo2Device &&
                route.label == 'Auth' &&
                size.width > size.height);
    final preserveIosRouteState =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final motionEnabled = widget.pageAnimations &&
        !MediaQuery.disableAnimationsOf(context) &&
        !isCompactLandscapeDevice(context);
    final body = AppBackground(
      child: AnimatedSwitcher(
        key: const ValueKey('route-switcher'),
        duration:
            motionEnabled ? const Duration(milliseconds: 360) : Duration.zero,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          if (!motionEnabled && !preserveIosRouteState) return child;
          final offset = motionEnabled
              ? Tween<Offset>(
                  begin: const Offset(0.015, 0.02),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                )
              : const AlwaysStoppedAnimation<Offset>(Offset.zero);
          return FadeTransition(
            opacity: motionEnabled
                ? animation
                : const AlwaysStoppedAnimation<double>(1),
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(route.label),
          child: route.builder(context),
        ),
      ),
    );
    return ScreenWakeLockScope(
      enabled: shouldKeepScreenAwakeForRoute(route.label),
      service: widget.screenWakeLockService,
      activityToken: _screenWakeFenActivityId,
      sessionKey: route.label,
      onIdleTimeout: _handleScreenWakeIdleTimeout,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        resizeToAvoidBottomInset: !keepKeyboardFromResizingBody,
        body: PopScope(
          canPop: !moveAndroidHomeToBackground &&
              (route.label == 'Home' ||
                  route.label == 'Auth' ||
                  route.label == 'Splash'),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (moveAndroidHomeToBackground) {
              unawaited(AndroidAppLifecycleService.moveToBackground());
              return;
            }
            if (route.label != 'Play' && route.label != 'ChessCom') {
              _goBack();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              body,
              if (_canUseIosBackSwipe(route.label))
                _IosBackSwipeEdge(
                  width: _iosBackSwipeEdgeWidth,
                  onStart: _handleIosBackSwipeStart,
                  onUpdate: _handleIosBackSwipeUpdate,
                  onEnd: _handleIosBackSwipeEnd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosBackSwipeEdge extends StatelessWidget {
  const _IosBackSwipeEdge({
    required this.width,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final double width;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: width,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('app-shell-ios-back-swipe-edge'),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: onStart,
          onHorizontalDragUpdate: onUpdate,
          onHorizontalDragEnd: onEnd,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _BoardLedSettingsGateway extends PhysicalBoardGateway {
  _BoardLedSettingsGateway(
    this._delegate, {
    required this.ledEnabled,
    this.boardInteractionEnabled = _alwaysEnableBoardInteraction,
  });

  final PhysicalBoardGateway _delegate;
  final bool Function() ledEnabled;
  final bool Function() boardInteractionEnabled;

  static bool _alwaysEnableBoardInteraction() => true;

  @override
  PhysicalBoardModel get boardModel => _delegate.boardModel;

  @override
  PhysicalBoardConnectionState get currentState => _delegate.currentState;

  @override
  String? get latestBoardFen =>
      boardInteractionEnabled() ? _delegate.latestBoardFen : null;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream => _delegate.stateStream;

  @override
  Stream<String> get boardFenStream =>
      _delegate.boardFenStream.where((_) => boardInteractionEnabled());

  @override
  Stream<BoardBatteryStatus> get boardBatteryStatusStream =>
      _delegate.boardBatteryStatusStream;

  @override
  Stream<String> get boardFirmwareVersionStream =>
      _delegate.boardFirmwareVersionStream;

  @override
  Stream<BoardFirmwareVersions> get boardFirmwareVersionsStream =>
      _delegate.boardFirmwareVersionsStream;

  @override
  Stream<List<ChessnutMovePieceStatus>> get movePieceStatusStream =>
      _delegate.movePieceStatusStream.where((_) => boardInteractionEnabled());

  @override
  bool get supportsStoredGameImport => _delegate.supportsStoredGameImport;

  @override
  Future<bool> connect() => _delegate.connect();

  @override
  Future<void> disconnect() => _delegate.disconnect();

  @override
  Future<bool> write(
    List<int> command, {
    bool withoutResponse = false,
  }) {
    return _delegate.write(command, withoutResponse: withoutResponse);
  }

  @override
  Future<bool> enableRealtimeFen() => _delegate.enableRealtimeFen();

  @override
  Future<bool> setMoveBoardFen(
    String fen, {
    bool strictMode = false,
    bool isReverse = false,
  }) {
    return _delegate.setMoveBoardFen(
      fen,
      strictMode: strictMode,
      isReverse: isReverse,
    );
  }

  @override
  Future<bool> stopMoveBoard() => _delegate.stopMoveBoard();

  @override
  Future<bool> setMoveLedSquares(Map<String, ChessnutMoveLedColor> squares) {
    if (!boardInteractionEnabled() || !ledEnabled()) {
      return _delegate.clearMoveLeds();
    }
    return _delegate.setMoveLedSquares(squares);
  }

  @override
  Future<bool> setGeneralLedSquares(Set<String> squares) {
    if (!boardInteractionEnabled() || !ledEnabled()) {
      return _delegate.clearGeneralLeds();
    }
    return _delegate.setGeneralLedSquares(squares);
  }

  @override
  Future<bool> setEvo2LedPatternsForFen(
    String boardOnlyFen,
    Evo2LedPatternSet patterns,
  ) {
    if (!boardInteractionEnabled() || !ledEnabled()) {
      return _delegate.clearGeneralLeds();
    }
    return _delegate.setEvo2LedPatternsForFen(boardOnlyFen, patterns);
  }

  @override
  Future<bool> setEvo2LedPatternKeys(
    List<String?> squarePatternKeys,
    Evo2LedPatternSet patterns,
  ) {
    if (!boardInteractionEnabled() || !ledEnabled()) {
      return _delegate.clearGeneralLeds();
    }
    return _delegate.setEvo2LedPatternKeys(squarePatternKeys, patterns);
  }

  @override
  Future<bool> clearMoveLeds() => _delegate.clearMoveLeds();

  @override
  Future<bool> clearGeneralLeds() => _delegate.clearGeneralLeds();

  @override
  Future<bool> setBoardBeepEnabled(bool enabled) {
    return _delegate.setBoardBeepEnabled(enabled);
  }

  @override
  Future<bool> playBeep({int frequency = 1000, int duration = 200}) {
    if (!boardInteractionEnabled()) return Future.value(false);
    return _delegate.playBeep(frequency: frequency, duration: duration);
  }

  @override
  Future<bool> queryGeneralBatteryStatus() {
    return _delegate.queryGeneralBatteryStatus();
  }

  @override
  Future<bool> queryBoardBatteryStatus() {
    return _delegate.queryBoardBatteryStatus();
  }

  @override
  Future<bool> queryMovePieceStatus() {
    return _delegate.queryMovePieceStatus();
  }

  @override
  Future<bool> queryBoardFirmwareVersion() {
    return _delegate.queryBoardFirmwareVersion();
  }

  @override
  Future<bool> queryGeneralBleVersion() {
    return _delegate.queryGeneralBleVersion();
  }

  @override
  Future<bool> queryGeneralMcuVersion() {
    return _delegate.queryGeneralMcuVersion();
  }

  @override
  Future<bool> queryGeneralFileCount() {
    return _delegate.queryGeneralFileCount();
  }

  @override
  Future<int?> queryMoveChannel() {
    return _delegate.queryMoveChannel();
  }

  @override
  Future<bool> setMoveChannel(int channel) {
    return _delegate.setMoveChannel(channel);
  }

  @override
  Future<int?> discoverMovePieceChannel() {
    return _delegate.discoverMovePieceChannel();
  }

  @override
  Future<List<String>?> queryMovePieceData() {
    return _delegate.queryMovePieceData();
  }

  @override
  Future<bool> setMovePieceData(List<String> names) {
    return _delegate.setMovePieceData(names);
  }

  @override
  Future<bool> startMovePiecePairing(int channel) {
    return _delegate.startMovePiecePairing(channel);
  }

  @override
  Future<bool> finishMovePiecePairing() {
    return _delegate.finishMovePiecePairing();
  }

  @override
  Future<bool> exitMovePiecePairing() {
    return _delegate.exitMovePiecePairing();
  }

  @override
  Future<bool> setMovePieceAutoPoweroff(bool enabled) {
    return _delegate.setMovePieceAutoPoweroff(enabled);
  }

  @override
  Future<int?> queryStoredGameCount() {
    return _delegate.queryStoredGameCount();
  }

  @override
  Future<String?> peekStoredGameFile() {
    return _delegate.peekStoredGameFile();
  }

  @override
  Future<String?> readAndDeleteStoredGameFile() {
    return _delegate.readAndDeleteStoredGameFile();
  }
}

class _ModuleGuideDialog extends StatelessWidget {
  const _ModuleGuideDialog({
    required this.definition,
    required this.hostContext,
    required this.hideMissingTargetSpotlight,
    required this.onDone,
  });

  final ModuleGuideDefinition definition;
  final BuildContext hostContext;
  final bool hideMissingTargetSpotlight;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _ModuleGuideCoachMarks(
      definition: definition,
      hostContext: hostContext,
      hideMissingTargetSpotlight: hideMissingTargetSpotlight,
      onDone: onDone,
    );
  }
}

class _ModuleGuideCoachMarks extends StatefulWidget {
  const _ModuleGuideCoachMarks({
    required this.definition,
    required this.hostContext,
    required this.hideMissingTargetSpotlight,
    required this.onDone,
  });

  final ModuleGuideDefinition definition;
  final BuildContext hostContext;
  final bool hideMissingTargetSpotlight;
  final VoidCallback onDone;

  @override
  State<_ModuleGuideCoachMarks> createState() => _ModuleGuideCoachMarksState();
}

class _ModuleGuideCoachMarksState extends State<_ModuleGuideCoachMarks> {
  int stepIndex = 0;
  Rect? targetRect;
  bool _targetUnavailable = false;
  int _targetResolveToken = 0;
  Timer? _targetRefreshTimer;
  int _targetRefreshTicks = 0;

  ModuleGuideStep get step {
    final steps = widget.definition.steps;
    if (steps.isEmpty) {
      return ModuleGuideStep(
        title: widget.definition.title,
        body: widget.definition.subtitle,
      );
    }
    return steps[stepIndex.clamp(0, steps.length - 1)];
  }

  bool get isLastStep => stepIndex >= widget.definition.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _updateTargetRect();
    _startTargetRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant _ModuleGuideCoachMarks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition != widget.definition) {
      stepIndex = 0;
      _updateTargetRect();
      _startTargetRefreshTimer();
    }
  }

  @override
  void dispose() {
    _targetRefreshTimer?.cancel();
    super.dispose();
  }

  void _startTargetRefreshTimer() {
    _targetRefreshTimer?.cancel();
    _targetRefreshTicks = 0;
    _targetRefreshTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) {
      if (!mounted || _targetRefreshTicks >= 12) {
        timer.cancel();
        if (identical(_targetRefreshTimer, timer)) {
          _targetRefreshTimer = null;
        }
        return;
      }
      _targetRefreshTicks += 1;
      _updateTargetRect();
    });
  }

  void _nextStep() {
    if (isLastStep) {
      widget.onDone();
      return;
    }
    final steps = widget.definition.steps;
    final nextStep = steps[(stepIndex + 1).clamp(0, steps.length - 1)];
    final nextRect = _targetRectForStep(nextStep);
    setState(() {
      stepIndex += 1;
      targetRect = nextRect?.inflate(8);
      _targetUnavailable = false;
    });
    _updateTargetRect();
    _startTargetRefreshTimer();
  }

  void _updateTargetRect() {
    final token = ++_targetResolveToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resolveTargetRect(token: token));
    });
  }

  Future<void> _resolveTargetRect({
    required int token,
    int attempt = 0,
  }) async {
    if (!mounted) return;
    final rootElement = widget.hostContext as Element;
    var viewport = _targetViewportRect();
    var elements = _elementsForStep(rootElement, step, viewport);
    final scrollTarget = _bestScrollableElementForElements(elements, viewport);
    if (scrollTarget != null) {
      await Scrollable.ensureVisible(
        scrollTarget,
        duration: Duration.zero,
        alignment: 0.5,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || token != _targetResolveToken) return;
      viewport = _targetViewportRect();
      elements = _elementsForStep(rootElement, step, viewport);
    }
    var rect = _bestVisibleRectForElements(elements, viewport);
    if (step.targetKey != null && rect == null && attempt < 6) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      unawaited(_resolveTargetRect(token: token, attempt: attempt + 1));
      return;
    }
    if (!mounted || token != _targetResolveToken) return;
    final nextRect = rect?.inflate(8);
    final nextUnavailable = step.targetKey != null && nextRect == null;
    if (targetRect == nextRect && _targetUnavailable == nextUnavailable) return;
    setState(() {
      targetRect = nextRect;
      _targetUnavailable = nextUnavailable;
    });
  }

  Rect? _targetRectForStep(ModuleGuideStep guideStep) {
    final rootElement = widget.hostContext as Element;
    final viewport = _targetViewportRect();
    final elements = _elementsForStep(rootElement, guideStep, viewport);
    return _bestVisibleRectForElements(elements, viewport);
  }

  Rect _viewportRect() {
    final overlayBox = _overlayRenderBox();
    if (overlayBox == null) {
      return Offset.zero & MediaQuery.sizeOf(context);
    }
    return Offset.zero & overlayBox.size;
  }

  Rect _targetViewportRect() {
    final viewport = _viewportRect();
    final padding = MediaQuery.viewPaddingOf(context);
    return Rect.fromLTRB(
      viewport.left + padding.left,
      viewport.top + padding.top,
      viewport.right - padding.right,
      viewport.bottom - padding.bottom,
    ).intersect(viewport);
  }

  bool _isFullyVisible(Rect rect, Rect viewport) {
    if (rect.isEmpty || viewport.isEmpty) return false;
    const tolerance = 1.0;
    return rect.left >= viewport.left - tolerance &&
        rect.top >= viewport.top - tolerance &&
        rect.right <= viewport.right + tolerance &&
        rect.bottom <= viewport.bottom + tolerance;
  }

  List<Element> _elementsForWidgetKey(Element rootElement, Key key) {
    final matches = <Element>[];

    void visit(Element element) {
      if (element.widget.key == key) {
        matches.add(element);
      }
      element.visitChildElements(visit);
    }

    visit(rootElement);
    return matches;
  }

  List<Element> _elementsForStep(
    Element rootElement,
    ModuleGuideStep guideStep,
    Rect viewport,
  ) {
    final key = guideStep.targetKey;
    final elements = key == null
        ? const <Element>[]
        : _elementsForWidgetKey(rootElement, key);
    if (_bestVisibleRectForElements(elements, viewport) != null) {
      return elements;
    }

    final fallbackKey = guideStep.fallbackTargetKey;
    if (fallbackKey == null) return elements;
    return _elementsForWidgetKey(rootElement, fallbackKey);
  }

  Rect? _bestVisibleRectForElements(List<Element> elements, Rect viewport) {
    Rect? best;
    var bestArea = 0.0;
    for (final element in elements) {
      final rect = _rectForElement(element);
      if (rect == null || rect.isEmpty) continue;
      final visible = rect.intersect(viewport);
      final area = visible.isEmpty ? 0.0 : visible.width * visible.height;
      if (area > bestArea) {
        best = rect;
        bestArea = area;
      } else {
        best ??= rect;
      }
    }
    return best;
  }

  Element? _bestScrollableElementForElements(
    List<Element> elements,
    Rect viewport,
  ) {
    Element? fallback;
    for (final element in elements) {
      final rect = _rectForElement(element);
      if (rect == null || rect.isEmpty) continue;
      final visible = rect.intersect(viewport);
      if (_isFullyVisible(rect, viewport)) return null;
      fallback ??= element;
      if (visible.isEmpty) return element;
    }
    return fallback;
  }

  Rect? _rectForElement(Element? element) {
    if (element == null) return null;
    if (element is RenderObjectElement && element.renderObject is RenderBox) {
      final renderObject = element.renderObject as RenderBox;
      if (!renderObject.attached || !renderObject.hasSize) return null;
      final topLeft = _localToOverlay(renderObject, Offset.zero);
      return topLeft & renderObject.size;
    }
    return _descendantRenderBoxUnion(element);
  }

  RenderBox? _overlayRenderBox() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.attached) {
      return renderObject;
    }
    return null;
  }

  Offset _localToOverlay(RenderBox renderObject, Offset point) {
    final overlayBox = _overlayRenderBox();
    if (overlayBox == null) {
      return renderObject.localToGlobal(point);
    }
    final globalPoint = renderObject.localToGlobal(point);
    final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
    return globalPoint - overlayOrigin;
  }

  Rect? _descendantRenderBoxUnion(Element element) {
    Rect? union;
    void visit(Element child) {
      if (child is RenderObjectElement && child.renderObject is RenderBox) {
        final renderObject = child.renderObject as RenderBox;
        if (renderObject.attached && renderObject.hasSize) {
          final rect =
              _localToOverlay(renderObject, Offset.zero) & renderObject.size;
          if (!rect.isEmpty && rect.isFinite) {
            union = union == null ? rect : union!.expandToInclude(rect);
          }
        }
      }
      child.visitChildElements(visit);
    }

    element.visitChildElements(visit);
    return union;
  }

  Rect _fallbackSpotlight(Size size) {
    final width = math.min(size.width * 0.58, 320.0);
    final height = math.min(size.height * 0.18, 120.0);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.38),
      width: width,
      height: height,
    );
  }

  Rect _calloutRect({
    required Size size,
    required Rect spotlight,
    required bool compactLandscape,
    required EdgeInsets safePadding,
  }) {
    final margin = compactLandscape ? 12.0 : 18.0;
    final gap = compactLandscape ? 8.0 : 16.0;
    final leftInset = margin + safePadding.left;
    final topInset = margin + safePadding.top;
    final rightInset = margin + safePadding.right;
    final bottomInset = margin + safePadding.bottom;
    final usableWidth = math.max(1.0, size.width - leftInset - rightInset);
    final usableHeight = math.max(1.0, size.height - topInset - bottomInset);
    final rightSpace = size.width - spotlight.right - rightInset - gap;
    final leftSpace = spotlight.left - leftInset - gap;
    final sideSpace = math.max(leftSpace, rightSpace);
    final width = compactLandscape
        ? sideSpace >= 430.0
            ? math.min(560.0, math.max(430.0, sideSpace))
            : math.min(560.0, usableWidth)
        : math.min(360.0, usableWidth);
    final height = compactLandscape
        ? math.min(usableHeight, 300.0)
        : math.min(usableHeight, 250.0);
    final minUsableHeight =
        compactLandscape ? math.min(height, 190.0) : math.min(height, 214.0);
    final maxLeft = math.max(leftInset, size.width - width - rightInset);
    final maxTop = math.max(topInset, size.height - height - bottomInset);

    if (compactLandscape) {
      if (rightSpace >= width) {
        return Rect.fromLTWH(
          spotlight.right + gap,
          (spotlight.center.dy - height / 2).clamp(topInset, maxTop),
          width,
          height,
        );
      }
      if (leftSpace >= width) {
        return Rect.fromLTWH(
          spotlight.left - gap - width,
          (spotlight.center.dy - height / 2).clamp(topInset, maxTop),
          width,
          height,
        );
      }
    }

    Rect centeredAt(double top, double rectHeight) {
      return Rect.fromLTWH(
        (spotlight.center.dx - width / 2).clamp(leftInset, maxLeft),
        top,
        width,
        rectHeight,
      );
    }

    final belowTop = spotlight.bottom + gap;
    final belowHeight = size.height - bottomInset - belowTop;
    if (belowHeight >= height) {
      return centeredAt(belowTop, height);
    }

    final aboveTop = spotlight.top - gap - height;
    if (aboveTop >= topInset) {
      return centeredAt(aboveTop, height);
    }

    final aboveHeight = spotlight.top - gap - topInset;
    if (belowHeight >= aboveHeight && belowHeight >= minUsableHeight) {
      return centeredAt(belowTop, math.min(height, belowHeight));
    }
    if (aboveHeight >= minUsableHeight) {
      final rectHeight = math.min(height, aboveHeight);
      return centeredAt(spotlight.top - gap - rectHeight, rectHeight);
    }

    return centeredAt(
      (spotlight.center.dy - height / 2).clamp(topInset, maxTop),
      height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    final rawSpotlight = targetRect ??
        (step.targetKey == null ||
                !_targetUnavailable ||
                !widget.hideMissingTargetSpotlight
            ? _fallbackSpotlight(size)
            : null);
    final spotlight = (rawSpotlight ?? Rect.zero).intersect(Offset.zero & size);
    final callout = _calloutRect(
      size: size,
      spotlight: spotlight,
      compactLandscape: compactLandscape,
      safePadding: MediaQuery.viewPaddingOf(context),
    );
    final stepCount = math.max(widget.definition.steps.length, 1);

    return Material(
      key: const ValueKey('module-guide-dialog'),
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _ModuleGuideScrimPainter(spotlight: spotlight),
          ),
          if (!spotlight.isEmpty)
            Positioned.fromRect(
              rect: spotlight,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('module-guide-spotlight'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.32),
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned.fromRect(
            rect: callout,
            child: DecoratedBox(
              key: const ValueKey('module-guide-callout'),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(compactLandscape ? 10 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compactLandscape ? 36 : 44,
                          height: compactLandscape ? 36 : 44,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.definition.icon,
                            size: 22,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.definition.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${stepIndex + 1} of $stepCount',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey('module-guide-scroll'),
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              step.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              step.body,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: compactLandscape ? 1.12 : 1.18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: compactLandscape ? 6 : 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: widget.onDone,
                          child: const Text('Skip'),
                        ),
                        const Spacer(),
                        if (!isLastStep)
                          FilledButton.icon(
                            key: const ValueKey('module-guide-next'),
                            onPressed: _nextStep,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Next'),
                          )
                        else
                          FilledButton.icon(
                            key: const ValueKey('module-guide-got-it'),
                            onPressed: widget.onDone,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Got it'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleGuideScrimPainter extends CustomPainter {
  const _ModuleGuideScrimPainter({required this.spotlight});

  final Rect spotlight;

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    final spotlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(spotlight, const Radius.circular(18)),
      );
    final overlay = Path.combine(
      PathOperation.difference,
      fullPath,
      spotlightPath,
    );
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant _ModuleGuideScrimPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight;
}

ChessnutBoardModel _appBoardModelFromPhysical(PhysicalBoardModel model) {
  return switch (model) {
    PhysicalBoardModel.air => ChessnutBoardModel.air,
    PhysicalBoardModel.airPlus => ChessnutBoardModel.airPlus,
    PhysicalBoardModel.pro => ChessnutBoardModel.pro,
    PhysicalBoardModel.go => ChessnutBoardModel.go,
    PhysicalBoardModel.evo => ChessnutBoardModel.evo,
    PhysicalBoardModel.evo2 => ChessnutBoardModel.evo2,
    PhysicalBoardModel.move => ChessnutBoardModel.move,
    PhysicalBoardModel.pi => ChessnutBoardModel.pi,
    PhysicalBoardModel.general => ChessnutBoardModel.unknown,
    PhysicalBoardModel.unknown => ChessnutBoardModel.unknown,
  };
}

bool _isLichessSnapshotCheckFailure(LichessGameSnapshot snapshot) {
  final error = snapshot.errorMessage?.trim();
  if (error == null || error.isEmpty) return false;
  return snapshot.status == null &&
      snapshot.winner == null &&
      snapshot.moves == null &&
      snapshot.initialFen == null;
}

String _lichessFailureMessage(String fallback, String? reason) {
  final detail = _cleanLichessFailureReason(reason);
  if (detail == null) return fallback;
  return '$fallback: $detail';
}

String? _cleanLichessFailureReason(String? reason) {
  final trimmed = reason?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}
