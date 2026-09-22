import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stockfish Android build is release-build friendly', () {
    final root = Directory.current;
    final pluginDir = Directory('${root.path}/third_party/stockfish');
    final gradleFile = File('${pluginDir.path}/android/build.gradle');
    final cmakeFile = File('${pluginDir.path}/android/CMakeLists.txt');
    final nnueDir = Directory('${pluginDir.path}/android/nnue');
    final bigNet = File('${nnueDir.path}/nn-c288c895ea92.nnue');
    final smallNet = File('${nnueDir.path}/nn-37f18f62d772.nnue');

    expect(pluginDir.existsSync(), isTrue);
    expect(gradleFile.existsSync(), isTrue);
    expect(cmakeFile.existsSync(), isTrue);

    final gradle = gradleFile.readAsStringSync();
    final cmake = cmakeFile.readAsStringSync();

    expect(gradle, contains('chessnutTargetAbis'));
    expect(gradle, isNot(contains("'arm64-v8a', 'armeabi-v7a', 'x86_64'")));
    expect(cmake, contains('NNUE_EMBEDDING_OFF'));
    expect(cmake, isNot(contains('ensure_nnue')));
    expect(
      cmake,
      isNot(contains(
        r'file(DOWNLOAD https://tests.stockfishchess.org/api/nn/nn-c288c895ea92.nnue ${CMAKE_BINARY_DIR}/nn-c288c895ea92.nnue)',
      )),
    );
    expect(bigNet.existsSync(), isTrue);
    expect(smallNet.existsSync(), isTrue);
    expect(bigNet.lengthSync(), greaterThan(100 * 1024 * 1024));
    expect(smallNet.lengthSync(), greaterThan(3 * 1024 * 1024));
  });

  test('Android packages Stockfish NNUE files once as application assets', () {
    final gradleFile =
        File('${Directory.current.path}/android/app/build.gradle.kts');
    final gradle = gradleFile.readAsStringSync();

    expect(gradle, contains('stockfishNnueDirectory'));
    expect(gradle, contains('third_party/stockfish/android/nnue'));
    expect(gradle, contains('assets.srcDir(stockfishNnueDirectory)'));
  });

  test('Android does not package duplicate Maia weights from LC0 plugin', () {
    final pluginPubspec = File(
      '${Directory.current.path}/third_party/leela_chess_zero/pubspec.yaml',
    );
    final pubspec = pluginPubspec.readAsStringSync();

    expect(pubspec, isNot(contains('assets/weights/maia-1900.pb.gz')));
  });

  test('Android exposes a streaming Stockfish NNUE extraction channel', () {
    final activityFile = File(
      '${Directory.current.path}/android/app/src/main/kotlin/'
      'com/chessnut/chessnutnext/MainActivity.kt',
    );
    final activity = activityFile.readAsStringSync();

    expect(activity, contains('chessnut/stockfish_networks'));
    expect(activity, contains('prepare'));
    expect(activity, contains('assets.open'));
    expect(activity, contains('nn-c288c895ea92.nnue'));
    expect(activity, contains('nn-37f18f62d772.nnue'));
  });

  test('Android release build sanitizes integration_test plugin registration',
      () {
    final gradleFile =
        File('${Directory.current.path}/android/app/build.gradle.kts');
    final gradle = gradleFile.readAsStringSync();

    expect(gradle, contains('sanitizeGeneratedPluginRegistrantForRelease'));
    expect(gradle, contains('IntegrationTestPlugin'));
    expect(gradle, contains('compileReleaseJavaWithJavac'));
    expect(gradle, contains('compileProfileJavaWithJavac'));
  });

  test('Android Play release builds use release keystore signing', () {
    final gradleFile =
        File('${Directory.current.path}/android/app/build.gradle.kts');
    final gradle = gradleFile.readAsStringSync();
    final gitignore =
        File('${Directory.current.path}/.gitignore').readAsStringSync();

    expect(gradle, contains('keystorePropertiesFile'));
    expect(gradle, contains('key.properties'));
    expect(gradle, contains('create("release")'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(
      gradle,
      contains(
        'Missing android/key.properties. Create it from key.properties.example before building Android APKs or AABs.',
      ),
    );
    expect(
      gradle,
      isNot(contains('signingConfigs.getByName("debug")')),
    );
    expect(gitignore, contains('key.properties'));
    expect(gitignore, contains('**/*.jks'));
    expect(gitignore, contains('**/*.jks'));
  });

  test('Android release signing template documents required fields', () {
    final template =
        File('${Directory.current.path}/android/key.properties.example');

    expect(template.existsSync(), isTrue);
    final content = template.readAsStringSync();
    expect(content, contains('storeFile='));
    expect(content, contains('storePassword='));
    expect(content, contains('keyAlias='));
    expect(content, contains('keyPassword='));
    expect(content, contains('release-keystore.jks'));
    expect(content, contains('keyAlias=release'));
    expect(content, isNot(contains('upload')));
    expect(content, isNot(contains('appSigning')));
  });

  test('Android local backend test builds allow loopback HTTP', () {
    final manifestFile = File(
        '${Directory.current.path}/android/app/src/main/AndroidManifest.xml');
    final manifest = manifestFile.readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android:usesCleartextTraffic="true"'));
  });

  test('AIDL active side only reflects physical USB reports', () {
    final serviceSource = File(
      '${Directory.current.path}/android/app/src/main/kotlin/'
      'com/chessnut/chessnutnext/UsbClockService.kt',
    ).readAsStringSync();
    final aidlSource = File(
      '${Directory.current.path}/android/app/src/main/aidl/'
      'com/chessnut/chessnutnext/clock/IUsbClockService.aidl',
    ).readAsStringSync();

    final inputHandler = serviceSource.substring(
      serviceSource.indexOf('private fun handleInputReport(data: ByteArray)'),
      serviceSource.indexOf('private fun broadcastButtonEvent'),
    );
    final setActiveSide = serviceSource.substring(
      serviceSource.indexOf('fun setActiveSide(side: ClockSide)'),
      serviceSource.indexOf('fun getLastButton()'),
    );

    expect(
      inputHandler,
      contains('lastReportedActiveSide = button'),
    );
    expect(setActiveSide, isNot(contains('lastReportedActiveSide')));
    expect(
      serviceSource,
      contains('fun getActiveSide(): ClockSide? = lastReportedActiveSide'),
    );
    expect(aidlSource, contains('setActiveSide() 不会影响此值'));
  });

  test('Chessnut clock Vision uses the A733 NPU with app cache storage', () {
    final serviceFile = File(
      '${Directory.current.path}/android/app/src/main/kotlin/'
      'com/chessnut/chessnutnext/BoardBackgroundConnectionService.kt',
    );
    final source = serviceFile.readAsStringSync();

    expect(source, contains('isChessnutClockDevice()'));
    expect(source, contains('yolov5ncnnSetBackend('));
    expect(source, contains('context.cacheDir.absolutePath'));
    expect(source, contains('BACKEND_A733_NPU'));
  });

  test('Vision accepts ncnn in-memory model byte count as CPU init success',
      () {
    final visionSource = File(
      '${Directory.current.path}/third_party/yolov5vision/src/yolov5ncnn.cpp',
    ).readAsStringSync();

    expect(
      visionSource,
      contains('param_result == 0 && model_result > 0'),
    );
  });

  test('Vision recognition sources do not emit application logs', () {
    final projectRoot = Directory.current.path;
    final serviceSource = File(
      '$projectRoot/android/app/src/main/kotlin/com/chessnut/chessnutnext/'
      'BoardBackgroundConnectionService.kt',
    ).readAsStringSync();
    final nativeSources = <String>[
      '$projectRoot/third_party/yolov5vision/src/yolov5ncnn.cpp',
      '$projectRoot/third_party/yolov5vision/src/yolov8ncnn_jni.cpp',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(serviceSource, isNot(contains('ChessnutVision')));
    expect(serviceSource, isNot(contains('VISION_LOG_TAG')));
    expect(serviceSource, isNot(contains('Log.')));
    expect(nativeSources, isNot(contains('__android_log_print')));
    expect(nativeSources, isNot(contains('YoloA733Npu')));
    expect(nativeSources, isNot(contains('DETECT_LOG')));
  });

  test('Vision bundles the A733 runtime only in Android arm64', () {
    final pluginRoot = '${Directory.current.path}/third_party/yolov5vision';
    const runtimeLibraries = <String>[
      'libawnn.viplite.so',
      'libVIPliteCompat.so',
      'libNBGlinker.so',
      'libVIPhal.so',
      'libc++.so',
    ];
    final visionSource =
        File('$pluginRoot/src/yolov5ncnn.cpp').readAsStringSync();

    for (final libraryName in runtimeLibraries) {
      final bundledLibrary = File(
        '$pluginRoot/android/src/main/jniLibs/arm64-v8a/$libraryName',
      );
      expect(bundledLibrary.existsSync(), isTrue, reason: libraryName);
      expect(bundledLibrary.lengthSync(), greaterThan(0), reason: libraryName);
    }
    expect(
      Directory('$pluginRoot/ios')
          .listSync(recursive: true)
          .whereType<File>()
          .any((file) => runtimeLibraries.any(file.path.endsWith)),
      isFalse,
    );
    expect(
      Directory('$pluginRoot/macos')
          .listSync(recursive: true)
          .whereType<File>()
          .any((file) => runtimeLibraries.any(file.path.endsWith)),
      isFalse,
    );
    expect(
      visionSource,
      contains('dlopen("libawnn.viplite.so", RTLD_NOW | RTLD_GLOBAL)'),
    );
    expect(visionSource, isNot(contains('/vendor/lib64/libawnn.viplite.so')));
    expect(visionSource, isNot(contains('/system/lib64/libawnn.viplite.so')));
  });

  test(
      'Android declares connected-device foreground service for board keepalive',
      () {
    final manifestFile = File(
        '${Directory.current.path}/android/app/src/main/AndroidManifest.xml');
    final manifest = manifestFile.readAsStringSync();

    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE'),
    );
    expect(manifest, contains('android.permission.WAKE_LOCK'));
    expect(
      manifest,
      contains('softwinner.permission.AWBACKGROUND_ACCESS'),
    );
    expect(manifest, contains('BoardBackgroundConnectionService'));
    expect(
        manifest, contains('android:foregroundServiceType="connectedDevice"'));
  });

  test('Android USB attachment does not auto-launch MainActivity', () {
    final manifest = File(
      '${Directory.current.path}/android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      isNot(contains('android.hardware.usb.action.USB_DEVICE_ATTACHED')),
    );
  });

  test('Android EVO2 power controller uses the firmware sysfs interface', () {
    final activity = File(
      '${Directory.current.path}/android/app/src/main/kotlin/com/chessnut/chessnutnext/MainActivity.kt',
    ).readAsStringSync();
    final controller = File(
      '${Directory.current.path}/android/app/src/main/kotlin/com/chessnut/chessnutnext/Evo2UsbPowerController.kt',
    ).readAsStringSync();

    expect(activity, contains('chessnut/evo2_power'));
    expect(activity, contains('chessnut/evo2_power/events'));
    expect(
      activity,
      contains('private const val EVO2_DEVICE_DETECTION_ENABLED = false'),
    );
    expect(controller, contains('/sys/class/bnd_gpio_en/enable'));
    expect(controller, contains('Intent.ACTION_SCREEN_OFF'));
    expect(controller, contains('Intent.ACTION_USER_PRESENT'));
    expect(controller, contains('PowerManager.PARTIAL_WAKE_LOCK'));
    expect(controller, contains('keepBoardConnectedEnabled && gameActive'));
    expect(controller, contains('if (usbPowerEnabled == enabled) return true'));
    expect(controller, contains('USB_POWER_FILE.readText().trim()'));
    expect(activity, contains('"setScreenOffPolicy"'));
    expect(activity, contains('if (isChessnutEvo2Device) return false'));
    expect(
        activity, contains('File("/sys/class/bnd_gpio_en/enable").exists()'));
    expect(
      activity,
      contains('get() = isChessnutClockDevice || isChessnutEvo2Device'),
    );
    expect(
      RegExp(
        r'if \(isChessnutClockDevice\) \{\s+'
        r'requestedOrientation = ActivityInfo\.SCREEN_ORIENTATION_LANDSCAPE',
      ).hasMatch(activity),
      isTrue,
    );
    expect(activity, contains('if (usesCompanionDisplayMode)'));
    expect(activity, isNot(contains('FLAG_KEEP_SCREEN_ON')));
    expect(
      activity,
      contains('flutterEngine.plugins.has(WakelockPlusPlugin::class.java)'),
    );
    expect(
      activity,
      contains('flutterEngine.plugins.add(WakelockPlusPlugin())'),
    );
  });

  test('Android EVO2 orientation controls the system and LED rotation', () {
    final manifest = File(
      '${Directory.current.path}/android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      '${Directory.current.path}/android/app/src/main/kotlin/com/chessnut/chessnutnext/MainActivity.kt',
    ).readAsStringSync();
    final service = File(
      '${Directory.current.path}/android/app/src/main/kotlin/com/chessnut/chessnutnext/Evo2BoardService.kt',
    ).readAsStringSync();
    final controller = File(
      '${Directory.current.path}/android/app/src/main/kotlin/com/chessnut/chessnutnext/Evo2UsbBoardController.kt',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.WRITE_SETTINGS'),
    );
    expect(activity, contains('Settings.System.ACCELEROMETER_ROTATION'));
    expect(activity, contains('Settings.System.USER_ROTATION'));
    expect(
      activity,
      contains('evo2BoardService?.setDisplayRotation(displayRotation)'),
    );
    expect(service, contains('fun setDisplayRotation(rotation: Int): Boolean'));
    expect(controller, contains('displayRotationOverride'));
    expect(controller, contains('displayRotationOverride?.let { return it }'));
  });

  test('Android exposes EVO2 board control through a shared AIDL broker', () {
    final manifest = File(
      '${Directory.current.path}/android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final service = File(
      '${Directory.current.path}/android/app/src/main/kotlin/com/chessnut/chessnutnext/Evo2BoardService.kt',
    ).readAsStringSync();
    final activity = File(
      '${Directory.current.path}/android/app/src/main/kotlin/com/chessnut/chessnutnext/MainActivity.kt',
    ).readAsStringSync();
    final aidl = File(
      '${Directory.current.path}/android/app/src/main/aidl/com/chessnut/chessnutnext/evo2/IEvo2BoardService.aidl',
    ).readAsStringSync();
    final listener = File(
      '${Directory.current.path}/android/app/src/main/aidl/com/chessnut/chessnutnext/evo2/IEvo2BoardListener.aidl',
    ).readAsStringSync();

    expect(manifest, contains('com.chessnut.chessnutnext.Evo2BoardService'));
    expect(
      manifest,
      contains('com.chessnut.chessnutnext.evo2.Evo2BoardService'),
    );
    expect(service, contains('IEvo2BoardService.Stub()'));
    expect(service, contains('RemoteCallbackList<IEvo2BoardListener>()'));
    expect(activity, contains('Evo2BoardService.LocalBinder'));
    expect(aidl, isNot(contains('boolean isAvailable()')));
    expect(aidl, isNot(contains('int getConnectionState()')));
    expect(aidl, isNot(contains('boolean connect()')));
    expect(aidl, isNot(contains('void disconnect()')));
    expect(aidl, contains('String getLatestFen()'));
    expect(aidl, contains('boolean requestFen()'));
    expect(aidl, contains('boolean setLedPatternPixels(in byte[] pixels)'));
    expect(aidl, contains('boolean writeLedCommand(in byte[] command)'));
    expect(listener, contains('void onFenChanged(String fen'));
  });

  test('iOS declares CoreBluetooth central background mode', () {
    final plistFile = File('${Directory.current.path}/ios/Runner/Info.plist');
    final plist = plistFile.readAsStringSync();

    expect(plist, contains('<key>UIBackgroundModes</key>'));
    expect(plist, contains('<string>bluetooth-central</string>'));
  });

  test('Apple apps declare microphone access for voice features', () {
    final iosPlist = File('${Directory.current.path}/ios/Runner/Info.plist')
        .readAsStringSync();
    final macosPlist = File('${Directory.current.path}/macos/Runner/Info.plist')
        .readAsStringSync();
    final macosDebugEntitlements = File(
      '${Directory.current.path}/macos/Runner/DebugProfile.entitlements',
    ).readAsStringSync();
    final macosReleaseEntitlements = File(
      '${Directory.current.path}/macos/Runner/Release.entitlements',
    ).readAsStringSync();

    expect(iosPlist, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(macosPlist, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(
      macosDebugEntitlements,
      contains('com.apple.security.device.audio-input'),
    );
    expect(
      macosReleaseEntitlements,
      contains('com.apple.security.device.audio-input'),
    );
  });

  test('macOS allows reading user-selected PGN files', () {
    final debugEntitlements = File(
      '${Directory.current.path}/macos/Runner/DebugProfile.entitlements',
    ).readAsStringSync();
    final releaseEntitlements = File(
      '${Directory.current.path}/macos/Runner/Release.entitlements',
    ).readAsStringSync();

    expect(
      debugEntitlements,
      contains('com.apple.security.files.user-selected.read-only'),
    );
    expect(
      releaseEntitlements,
      contains('com.apple.security.files.user-selected.read-only'),
    );
  });

  test('macOS window keeps the 1920 by 1080 layout aspect ratio', () {
    final windowSource = File(
      '${Directory.current.path}/macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();

    expect(
      windowSource,
      contains('preferredContentSize = NSSize(width: 1920, height: 1080)'),
    );
    expect(
      windowSource,
      contains('minimumContentSize = NSSize(width: 960, height: 540)'),
    );
    expect(
      windowSource,
      contains('fixedContentAspectRatio = NSSize(width: 16, height: 9)'),
    );
    expect(windowSource, contains('self.contentAspectRatio ='));
    expect(windowSource, contains('self.setContentSize('));
  });

  test('macOS Stockfish helper inherits the app sandbox only', () {
    final entitlementsFile =
        File('${Directory.current.path}/macos/Runner/Stockfish.entitlements');
    final entitlements = entitlementsFile.readAsStringSync();

    expect(entitlements, contains('com.apple.security.inherit'));
    expect(entitlements, isNot(contains('com.apple.security.app-sandbox')));
  });

  test('macOS LC0 helper is built, bundled, and sandbox-inherited', () {
    final projectFile = File(
        '${Directory.current.path}/macos/Runner.xcodeproj/project.pbxproj');
    final scriptFile = File(
      '${Directory.current.path}/macos/Runner/Scripts/build_lc0_engine.sh',
    );
    final entitlementsFile =
        File('${Directory.current.path}/macos/Runner/Lc0.entitlements');
    final mesonFile = File(
      '${Directory.current.path}/third_party/leela_chess_zero/ios/lc0/meson.build',
    );

    final project = projectFile.readAsStringSync();
    final script = scriptFile.readAsStringSync();
    final entitlements = entitlementsFile.readAsStringSync();
    final meson = mesonFile.readAsStringSync();

    expect(project, contains('Bundle LC0 Engine'));
    expect(project, contains('build_lc0_engine.sh'));
    expect(project, contains('Runner/Lc0.entitlements'));
    expect(
      project,
      contains(r'$(TARGET_BUILD_DIR)/$(EXECUTABLE_FOLDER_PATH)/lc0'),
    );
    expect(script, contains(r'"${MESON}" setup'));
    expect(script, contains('aarch64-darwin'));
    expect(script, contains('x86_64-darwin'));
    expect(script, contains('lipo -create'));
    expect(script, contains('https://pypi.tuna.tsinghua.edu.cn/simple'));
    expect(entitlements, contains('com.apple.security.inherit'));
    expect(entitlements, isNot(contains('com.apple.security.app-sandbox')));
    expect(meson, contains("get_option('dag_classic')"));
    expect(meson, contains("dependency('eigen3', required: false)"));
    expect(meson, contains("'src/utils/lc0_string.cc'"));
  });

  test('Android home widgets are registered with Flutter bridge channel', () {
    final manifestFile = File(
        '${Directory.current.path}/android/app/src/main/AndroidManifest.xml');
    final activityFile = File(
      '${Directory.current.path}/android/app/src/main/kotlin/'
      'com/chessnut/chessnutnext/MainActivity.kt',
    );
    final providerFile = File(
      '${Directory.current.path}/android/app/src/main/kotlin/'
      'com/chessnut/chessnutnext/ChessnutHomeWidgetProvider.kt',
    );

    final manifest = manifestFile.readAsStringSync();
    final activity = activityFile.readAsStringSync();
    final provider = providerFile.readAsStringSync();

    expect(manifest,
        contains('com.chessnut.chessnutnext.ChessnutHomeWidgetProvider'));
    expect(manifest,
        contains('com.chessnut.chessnutnext.ChessnutQuickPlayWidgetProvider'));
    expect(
        manifest, contains('com.chessnut.chessnut.ChessnutHomeWidgetReceiver'));
    expect(manifest, contains('@xml/widget_board_console_info'));
    expect(manifest, contains('@xml/widget_quick_play_info'));
    expect(manifest, contains('@xml/widget_legacy_home_info'));
    expect(activity, contains('chessnut/home_widget'));
    expect(provider, contains('ACTION_TOGGLE_VISION'));
    expect(provider, contains('ACTION_WIDGET_LAUNCH'));
  });

  test('Android home widget layouts avoid unsupported RemoteViews tags', () {
    final layoutDir =
        Directory('${Directory.current.path}/android/app/src/main/res/layout');
    final widgetLayouts = layoutDir
        .listSync()
        .whereType<File>()
        .where((file) => file.uri.pathSegments.last.startsWith('widget_'));

    for (final file in widgetLayouts) {
      final xml = file.readAsStringSync();
      expect(
        xml,
        isNot(contains(RegExp(r'<\s*View(\s|>)'))),
        reason:
            '${file.path} uses android.view.View, which RemoteViews rejects.',
      );
    }
  });

  test('Android board console widget exposes richer quick actions', () {
    final layout = File(
      '${Directory.current.path}/android/app/src/main/res/layout/'
      'widget_board_console.xml',
    ).readAsStringSync();
    final provider = File(
      '${Directory.current.path}/android/app/src/main/kotlin/'
      'com/chessnut/chessnutnext/ChessnutHomeWidgetProvider.kt',
    ).readAsStringSync();

    expect(layout, contains('widget_date'));
    expect(layout, contains('widget_records_action'));
    expect(layout, contains('widget_last_game_chip'));
    expect(layout, contains('widget_primary_action_shell'));
    expect(provider, contains('records'));
    expect(provider, contains('launchPendingIntent(context, "continueGame")'));
    expect(provider,
        isNot(contains('setTextViewText(R.id.widget_records_action')));
    expect(provider, contains('if (!isCompact)'));
  });

  test('Android home widget battery text uses launcher-safe ASCII bars', () {
    final provider = File(
      '${Directory.current.path}/android/app/src/main/kotlin/'
      'com/chessnut/chessnutnext/ChessnutHomeWidgetProvider.kt',
    ).readAsStringSync();

    expect(provider, contains('val filled = "|".repeat'));
    expect(provider, contains('val empty = "-".repeat'));
  });
}
