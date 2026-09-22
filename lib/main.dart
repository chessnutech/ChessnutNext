import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:chessnut_flutter_export/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'l10n/localized_material.dart';
import 'screens/app_shell.dart';
import 'screens/analysis_screen.dart' show AnalysisPgnFileLoader;
import 'screens/course_screen.dart';
import 'services/app_preferences_store.dart';
import 'services/app_shared_preferences.dart';
import 'services/android_home_widget_service.dart';
import 'services/auth_service.dart';
import 'services/board_background_connection_service.dart';
import 'services/chess_clock_switch_service.dart';
import 'services/device_performance_service.dart';
import 'services/evo2_display_service.dart';
import 'services/evo2_usb_power_service.dart';
import 'services/lc0_weight_library_service.dart';
import 'services/login_credential_store.dart';
import 'services/local_game_record_store.dart';
import 'services/network_latency_service.dart';
import 'services/physical_board_gateway.dart';
import 'services/recaptcha_service.dart';
import 'services/report_share_service.dart';
import 'services/review_prompt_service.dart';
import 'services/session_store.dart';
import 'services/app_sound_service.dart';
import 'services/stockfish_analysis_service.dart';
import 'services/windows_display_power_service.dart';
import 'services/course_lesson_service.dart';
import 'services/course_progress_service.dart';
import 'screens/engine_lab_screen.dart';
import 'theme/chessnut_theme.dart';
import 'widgets/turnstile_challenge_dialog.dart';
import 'widgets/lichess_authorization_dialog.dart';
import 'widgets/app_chrome.dart' show hasFocusedTextInput;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await AppSharedPreferences.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ChessnutApp());
}

class ChessnutApp extends StatefulWidget {
  const ChessnutApp({
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
    this.evo2DisplayService = const MethodChannelEvo2DisplayService(),
    this.clockSwitchService,
    this.devicePerformanceService,
    this.networkLatencyProbe,
    this.reviewPromptService,
    this.reportShareService,
    this.courseLessonRepository,
    this.courseVideoAdapterFactory,
    this.analysisPgnFileLoader,
    this.modelBuildPgnFileLoader,
    this.modelBuildFileImportAvailableOverride,
    this.lc0WeightLibraryStore,
    this.initialScreen,
    this.appSoundService = const SystemAppSoundService(),
    this.windowsDisplayPowerService =
        const MethodChannelWindowsDisplayPowerService(),
    this.turnstileChallengePresenter = showTurnstileChallenge,
    this.lichessAuthorizationPresenter = showLichessAuthorization,
    super.key,
  });

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
  final Evo2DisplayService evo2DisplayService;
  final ChessClockSwitchService? clockSwitchService;
  final DevicePerformanceService? devicePerformanceService;
  final NetworkLatencyProbe? networkLatencyProbe;
  final ReviewPromptService? reviewPromptService;
  final ReportShareService? reportShareService;
  final CourseLessonRepository? courseLessonRepository;
  final CourseVideoAdapter Function()? courseVideoAdapterFactory;
  final AnalysisPgnFileLoader? analysisPgnFileLoader;
  final ModelBuildPgnFileLoader? modelBuildPgnFileLoader;
  final bool? modelBuildFileImportAvailableOverride;
  final Lc0WeightLibraryStore? lc0WeightLibraryStore;
  final String? initialScreen;
  final AppSoundService appSoundService;
  final WindowsDisplayPowerService windowsDisplayPowerService;
  final TurnstileChallengePresenter turnstileChallengePresenter;
  final LichessAuthorizationPresenter lichessAuthorizationPresenter;

  @override
  State<ChessnutApp> createState() => _ChessnutAppState();
}

class _ChessnutAppState extends State<ChessnutApp> {
  ThemeMode themeMode = AppSharedPreferences.defaultThemeMode;
  ChessnutVisualTheme visualTheme = AppSharedPreferences.defaultVisualTheme;
  bool visualEffectsEnabled = AppSharedPreferences.defaultVisualEffectsEnabled;
  bool visualEffectsLocked = false;
  bool isChessnutClockDevice = false;
  bool isChessnutEvo2Device = false;
  AppLanguagePreference languagePreference =
      AppSharedPreferences.defaultLanguagePreference;
  Evo2ScreenOrientation evo2ScreenOrientation =
      AppSharedPreferences.defaultEvo2ScreenOrientation;
  bool boardCoordinatesEnabled =
      AppSharedPreferences.defaultBoardCoordinatesEnabled;
  bool keepBoardConnectedInBackground =
      AppSharedPreferences.defaultKeepBoardConnectedInBackground;
  bool soundEffectsEnabled = AppSharedPreferences.defaultSoundEffectsEnabled;
  bool moveAnnouncementEnabled =
      AppSharedPreferences.defaultMoveAnnouncementEnabled;
  SoundEffectsSettings soundEffects = const SoundEffectsSettings(
    fromTo: AppSharedPreferences.defaultSoundFromTo,
    move: AppSharedPreferences.defaultSoundMove,
    result: AppSharedPreferences.defaultSoundResult,
    keyAction: AppSharedPreferences.defaultSoundKeyAction,
  );
  bool? _lastCompactChrome;
  late final AppPreferencesStore _appPreferencesStore;
  late final DevicePerformanceService _devicePerformanceService;

  @override
  void initState() {
    super.initState();
    _appPreferencesStore =
        widget.appPreferencesStore ?? const FileAppPreferencesStore();
    _devicePerformanceService = widget.devicePerformanceService ??
        const MethodChannelDevicePerformanceService();
    _loadAppSettings();
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => themeMode = mode);
    AppSharedPreferences.set(AppSettingKeys.themeMode, mode.name);
  }

  void setVisualTheme(ChessnutVisualTheme theme) {
    setState(() => visualTheme = theme);
    AppSharedPreferences.set(AppSettingKeys.visualTheme, theme.name);
  }

  void setVisualEffectsEnabled(bool enabled) {
    if (visualEffectsLocked && enabled) return;
    setState(() => visualEffectsEnabled = enabled);
    AppSharedPreferences.set(AppSettingKeys.visualEffectsEnabled, enabled);
  }

  void setLanguagePreference(AppLanguagePreference preference) {
    setState(() => languagePreference = preference);
    AppSharedPreferences.set(AppSettingKeys.language, preference.tag);
  }

  void setBoardCoordinatesEnabled(bool enabled) {
    setState(() => boardCoordinatesEnabled = enabled);
    AppSharedPreferences.set(AppSettingKeys.boardCoordinatesEnabled, enabled);
  }

  void setKeepBoardConnectedInBackground(bool enabled) {
    final nextEnabled = _macScreenOffPlayIsAlwaysEnabled ? true : enabled;
    setState(() => keepBoardConnectedInBackground = nextEnabled);
    AppSharedPreferences.set(
      AppSettingKeys.keepBoardConnectedInBackground,
      nextEnabled,
    );
  }

  bool get _macScreenOffPlayIsAlwaysEnabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  void setEvo2ScreenOrientation(Evo2ScreenOrientation orientation) {
    setState(() => evo2ScreenOrientation = orientation);
    AppSharedPreferences.set(
      AppSettingKeys.evo2ScreenOrientation,
      orientation.storageKey,
    );
    if (isChessnutEvo2Device) {
      widget.evo2DisplayService.setScreenOrientation(orientation).ignore();
    }
  }

  void setSoundEffectsEnabled(bool enabled) {
    setState(() => soundEffectsEnabled = enabled);
    AppSharedPreferences.set(AppSettingKeys.soundEffectsEnabled, enabled);
  }

  void setMoveAnnouncementEnabled(bool enabled) {
    setState(() => moveAnnouncementEnabled = enabled);
    AppSharedPreferences.set(AppSettingKeys.moveAnnouncementEnabled, enabled);
  }

  void setSoundEffects(SoundEffectsSettings settings) {
    setState(() => soundEffects = settings);
    AppSharedPreferences.set(AppSettingKeys.soundFromTo, settings.fromTo);
    AppSharedPreferences.set(AppSettingKeys.soundMove, settings.move);
    AppSharedPreferences.set(AppSettingKeys.soundResult, settings.result);
    AppSharedPreferences.set(AppSettingKeys.soundKeyAction, settings.keyAction);
  }

  Future<void> _loadAppSettings() async {
    final storedTheme =
        AppSharedPreferences.get<String>(AppSettingKeys.visualTheme);
    final storedThemeMode =
        AppSharedPreferences.get<String>(AppSettingKeys.themeMode);
    var nextTheme = ChessnutVisualTheme.values.firstWhere(
      (theme) => theme.name == storedTheme,
      orElse: () => AppSharedPreferences.defaultVisualTheme,
    );
    var nextEffects =
        AppSharedPreferences.get<bool>(AppSettingKeys.visualEffectsEnabled);
    var nextEffectsLocked = false;
    var nextKeepBoardConnected = AppSharedPreferences.get<bool>(
      AppSettingKeys.keepBoardConnectedInBackground,
    );
    final profile = await _devicePerformanceService.readProfile();

    if (_macScreenOffPlayIsAlwaysEnabled && !nextKeepBoardConnected) {
      nextKeepBoardConnected = true;
      AppSharedPreferences.set(
        AppSettingKeys.keepBoardConnectedInBackground,
        true,
      );
    }

    if (profile != null && profile.requiresVisualEffectsDisabled) {
      nextEffectsLocked = true;
      if (nextEffects) {
        nextEffects = false;
        AppSharedPreferences.set(
          AppSettingKeys.visualEffectsEnabled,
          false,
        );
      }
    } else if (!AppSharedPreferences.containsKey(AppSettingKeys.visualTheme) ||
        !AppSharedPreferences.containsKey(
          AppSettingKeys.visualEffectsEnabled,
        )) {
      if (profile != null &&
          profile.prefersClassicLowEffects &&
          !AppSharedPreferences.get<bool>(
            AppSettingKeys.autoPerformanceApplied,
          )) {
        nextTheme = !AppSharedPreferences.containsKey(
          AppSettingKeys.visualTheme,
        )
            ? ChessnutVisualTheme.classic
            : nextTheme;
        nextEffects = AppSharedPreferences.containsKey(
          AppSettingKeys.visualEffectsEnabled,
        )
            ? AppSharedPreferences.get<bool>(
                AppSettingKeys.visualEffectsEnabled,
              )
            : false;
        AppSharedPreferences.set(AppSettingKeys.visualTheme, nextTheme.name);
        AppSharedPreferences.set(
          AppSettingKeys.visualEffectsEnabled,
          nextEffects,
        );
        AppSharedPreferences.set(
          AppSettingKeys.autoPerformanceApplied,
          true,
        );
      }
    }

    final nextThemeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == storedThemeMode,
      orElse: () => AppSharedPreferences.defaultThemeMode,
    );
    final nextEvo2Orientation = Evo2ScreenOrientation.fromStorage(
      AppSharedPreferences.get<String>(AppSettingKeys.evo2ScreenOrientation),
    );
    final nextSoundEffects = SoundEffectsSettings(
      fromTo: AppSharedPreferences.get<bool>(AppSettingKeys.soundFromTo),
      move: AppSharedPreferences.get<bool>(AppSettingKeys.soundMove),
      result: AppSharedPreferences.get<bool>(AppSettingKeys.soundResult),
      keyAction: AppSharedPreferences.get<bool>(AppSettingKeys.soundKeyAction),
    );

    if (!mounted) return;
    setState(() {
      languagePreference = AppLanguagePreference.fromTag(
        AppSharedPreferences.get<String>(AppSettingKeys.language),
      );
      themeMode = nextThemeMode;
      visualTheme = nextTheme;
      visualEffectsEnabled = nextEffects;
      visualEffectsLocked = nextEffectsLocked;
      isChessnutClockDevice = profile?.isChessnutClock == true;
      isChessnutEvo2Device = profile?.isChessnutEvo2 == true;
      evo2ScreenOrientation = nextEvo2Orientation;
      boardCoordinatesEnabled = AppSharedPreferences.get<bool>(
        AppSettingKeys.boardCoordinatesEnabled,
      );
      keepBoardConnectedInBackground = nextKeepBoardConnected;
      soundEffectsEnabled =
          AppSharedPreferences.get<bool>(AppSettingKeys.soundEffectsEnabled);
      moveAnnouncementEnabled = AppSharedPreferences.get<bool>(
        AppSettingKeys.moveAnnouncementEnabled,
      );
      soundEffects = nextSoundEffects;
    });

    if (profile?.isChessnutEvo2 == true) {
      widget.evo2DisplayService
          .setScreenOrientation(nextEvo2Orientation)
          .ignore();
    }
  }

  void _updateSystemChrome(BuildContext context) {
    if ((MediaQuery.viewInsetsOf(context).bottom > 0 ||
            hasFocusedTextInput()) &&
        _lastCompactChrome != null) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = size.width >= 900 && size.height <= 560;
    if (_lastCompactChrome == compactLandscape) return;
    _lastCompactChrome = compactLandscape;

    if (compactLandscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      return;
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  bool _protectAndroidPhoneLandscapeFromSystemNavigation(
    BuildContext context,
  ) {
    final size = MediaQuery.sizeOf(context);
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !isChessnutClockDevice &&
        size.width > size.height &&
        size.width < 1000 &&
        size.height < 600;
  }

  @override
  Widget build(BuildContext context) {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final apiLanguage = languagePreference.apiLanguage(systemLocale);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chessnut',
      locale: languagePreference.locale,
      supportedLocales: AppLanguagePreference.supportedLocales,
      localizationsDelegates: AppStrings.localizationsDelegates,
      localeResolutionCallback: (locale, supportedLocales) =>
          AppLanguagePreference.resolve(locale, supportedLocales),
      theme: ChessnutTheme.light(visualTheme, visualEffectsEnabled),
      darkTheme: ChessnutTheme.dark(visualTheme, visualEffectsEnabled),
      themeMode: themeMode,
      builder: (context, child) {
        _updateSystemChrome(context);
        var content = child ?? const SizedBox.shrink();
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
          content = _MacOsResponsiveCanvas(child: content);
        }
        if (!_protectAndroidPhoneLandscapeFromSystemNavigation(context)) {
          return content;
        }
        return SafeArea(
          top: false,
          bottom: false,
          child: content,
        );
      },
      home: AppShell(
        themeMode: themeMode,
        onThemeModeChanged: setThemeMode,
        visualTheme: visualTheme,
        onVisualThemeChanged: setVisualTheme,
        pageAnimations: visualEffectsEnabled,
        onPageAnimationsChanged: setVisualEffectsEnabled,
        hidePageAnimationsSetting: visualEffectsLocked,
        isChessnutClockDevice: isChessnutClockDevice,
        isChessnutEvo2Device: isChessnutEvo2Device,
        evo2ScreenOrientation: evo2ScreenOrientation,
        onEvo2ScreenOrientationChanged: setEvo2ScreenOrientation,
        boardCoordinatesEnabled: boardCoordinatesEnabled,
        onBoardCoordinatesChanged: setBoardCoordinatesEnabled,
        keepBoardConnectedInBackground: keepBoardConnectedInBackground,
        onKeepBoardConnectedInBackgroundChanged:
            setKeepBoardConnectedInBackground,
        soundEffectsEnabled: soundEffectsEnabled,
        onSoundEffectsChanged: setSoundEffectsEnabled,
        moveAnnouncementEnabled: moveAnnouncementEnabled,
        onMoveAnnouncementChanged: setMoveAnnouncementEnabled,
        soundEffects: soundEffects,
        onSoundEffectsSettingsChanged: setSoundEffects,
        appSoundService: widget.appSoundService,
        windowsDisplayPowerService: widget.windowsDisplayPowerService,
        languagePreference: languagePreference,
        onLanguagePreferenceChanged: setLanguagePreference,
        apiLanguage: apiLanguage,
        httpClient: widget.httpClient,
        recaptchaService: widget.recaptchaService,
        positionAnalyzer: widget.positionAnalyzer,
        boardGateway: widget.boardGateway,
        authService: widget.authService,
        sessionStore: widget.sessionStore,
        credentialStore: widget.credentialStore,
        appPreferencesStore: _appPreferencesStore,
        localGameRecordStore: widget.localGameRecordStore,
        androidHomeWidgetService: widget.androidHomeWidgetService,
        boardBackgroundConnectionService:
            widget.boardBackgroundConnectionService,
        evo2UsbPowerService: widget.evo2UsbPowerService,
        clockSwitchService: widget.clockSwitchService,
        networkLatencyProbe: widget.networkLatencyProbe,
        reviewPromptService: widget.reviewPromptService,
        reportShareService: widget.reportShareService,
        courseLessonRepository: widget.courseLessonRepository,
        courseProgressStore:
            AppPreferencesCourseProgressStore(_appPreferencesStore),
        courseVideoAdapterFactory: widget.courseVideoAdapterFactory,
        analysisPgnFileLoader: widget.analysisPgnFileLoader,
        modelBuildPgnFileLoader: widget.modelBuildPgnFileLoader,
        modelBuildFileImportAvailableOverride:
            widget.modelBuildFileImportAvailableOverride,
        lc0WeightLibraryStore: widget.lc0WeightLibraryStore,
        initialScreen: widget.initialScreen,
        turnstileChallengePresenter: widget.turnstileChallengePresenter,
        lichessAuthorizationPresenter: widget.lichessAuthorizationPresenter,
      ),
    );
  }
}

class _MacOsResponsiveCanvas extends StatelessWidget {
  const _MacOsResponsiveCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final adaptiveTextScale = switch (width) {
      < 1100 => 1.10,
      < 1450 => 1.08,
      < 1750 => 1.05,
      _ => 1.03,
    };
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(adaptiveTextScale),
      ),
      child: child,
    );
  }
}
