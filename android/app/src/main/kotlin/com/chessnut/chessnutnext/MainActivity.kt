package com.chessnut.chessnutnext

import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.app.KeyguardManager
import android.graphics.Path
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.app.ActivityManager
import android.provider.Settings
import android.view.View
import android.view.Surface
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import com.navideck.universal_ble.UniversalBleShutdown
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import dev.fluttercommunity.plus.wakelock.WakelockPlusPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val performanceChannel = "chessnut/device_performance"
    private val boardBackgroundChannel = "chessnut/board_background_connection"
    private val stockfishNetworkChannel = "chessnut/stockfish_networks"
    private val clockMethodChannel = "chessnut/clock_hid"
    private val clockEventChannel = "chessnut/clock_hid/events"
    private val homeWidgetChannel = "chessnut/home_widget"
    private val accessibilityVisionChannel = "chessnut/accessibility_vision"
    private val playInAppUpdateChannel = "chessnut/play_in_app_update"
    private val appLifecycleChannel = "chessnut/app_lifecycle"
    private val evo2BoardMethodChannel = "chessnut/evo2_board"
    private val evo2BoardEventChannel = "chessnut/evo2_board/events"
    private val evo2PowerMethodChannel = "chessnut/evo2_power"
    private val evo2PowerEventChannel = "chessnut/evo2_power/events"
    private val evo2DisplayMethodChannel = "chessnut/evo2_display"
    private var pendingWidgetAction: MutableMap<String, Any?>? = null
    private var activityResumed = false
    private var visionNotificationPermissionRequested = false
    private val visionNotificationPermissionRequestCode = 3102
    private lateinit var appUpdateManager: AppUpdateManager
    private val appUpdateListener = InstallStateUpdatedListener { state ->
        if (state.installStatus() == InstallStatus.DOWNLOADED) {
            appUpdateManager.completeUpdate()
        }
    }

    private val stockfishNnueFiles = mapOf(
        "nn-c288c895ea92.nnue" to 108919594L,
        "nn-37f18f62d772.nnue" to 3519630L
    )

    private var usbClockService: UsbClockService? = null
    private var clockEventSink: EventChannel.EventSink? = null
    private var evo2BoardService: Evo2BoardService? = null
    private var evo2BoardEventSink: EventChannel.EventSink? = null
    private var evo2UsbPowerController: Evo2UsbPowerController? = null
    private var evo2PowerEventSink: EventChannel.EventSink? = null
    private var evo2HardwareDetected = false
    private var evo2DisplayRotation: Int? = null
    private var evo2LedDisplayRotation: Int? = null
    private var isBound = false
    private var evo2BoardBound = false
    private var evo2BoardBinding = false
    private var evo2ConnectRequested = false

    // 主线程 Handler，确保 EventSink 调用在主线程
    private val mainHandler = Handler(Looper.getMainLooper())
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val localBinder = binder as? UsbClockService.LocalBinder
            usbClockService = localBinder?.getService()
            isBound = true

            // 设置监听器
            usbClockService?.setListener(object : UsbClockService.UsbClockListener {
                override fun onConnectionStateChanged(state: UsbClockService.ConnectionState) {
                    mainHandler.post {
                        clockEventSink?.success(mapOf(
                            "type" to "connection",
                            "state" to state.name
                        ))
                    }
                }

                override fun onButtonEvent(event: UsbClockService.ButtonEvent) {
                    mainHandler.post {
                        clockEventSink?.success(mapOf(
                            "type" to "button",
                            "button" to event.button.name,
                            "pressed" to event.pressed,
                            "timestamp" to event.timestamp
                        ))
                    }
                }

                override fun onError(error: String) {
                    mainHandler.post {
                        clockEventSink?.error("USB_ERROR", error, null)
                    }
                }
            })

            // 自动尝试连接
            usbClockService?.connect()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            usbClockService = null
            isBound = false
        }
    }

    private val evo2BoardServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val localBinder = binder as? Evo2BoardService.LocalBinder
            evo2BoardService = localBinder?.getService()
            evo2BoardBound = evo2BoardService != null
            evo2BoardBinding = false
            evo2BoardService?.setListener(evo2BoardListener)
            evo2LedDisplayRotation?.let { rotation ->
                evo2BoardService?.setDisplayRotation(rotation)
            }
            if (evo2ConnectRequested) {
                evo2BoardService?.connect()
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            evo2BoardService = null
            evo2BoardBound = false
            evo2BoardBinding = false
        }
    }

    private val evo2BoardListener = object : Evo2BoardService.Listener {
        override fun onConnectionStateChanged(state: Evo2UsbBoardController.ConnectionState) {
            evo2BoardEventSink?.success(mapOf(
                "type" to "connection",
                "state" to state.name
            ))
        }

        override fun onFenChanged(fen: String, rawPayload: ByteArray) {
            evo2BoardEventSink?.success(mapOf(
                "type" to "fen",
                "fen" to fen,
                "data" to rawPayload
            ))
        }

        override fun onResponse(payload: ByteArray) {
            evo2BoardEventSink?.success(mapOf(
                "type" to "response",
                "data" to payload
            ))
        }

        override fun onError(error: String) {
            evo2BoardEventSink?.success(mapOf(
                "type" to "error",
                "message" to error
            ))
        }
    }

    private val isChessnutClockDevice: Boolean
        get() {
            if (isChessnutEvo2Device) return false
            return Build.MODEL.equals("Chessnut_Companion", ignoreCase = true) &&
                Build.MANUFACTURER.equals("Chessnut", ignoreCase = true)
        }

    private val isChessnutEvo2Device: Boolean
        get() {
            if (!EVO2_DEVICE_DETECTION_ENABLED) return false
            if (evo2HardwareDetected) return true
            val normalizedModel = Build.MODEL.lowercase()
                .replace(Regex("[^a-z0-9]"), "")
            val normalizedManufacturer = Build.MANUFACTURER.lowercase()
                .replace(Regex("[^a-z0-9]"), "")
            evo2HardwareDetected = normalizedModel.contains("chessnutevo2") ||
                normalizedModel.contains("evo2") ||
                (normalizedModel == "a733pro3" &&
                    normalizedManufacturer.contains("allwinner")) ||
                File("/sys/class/bnd_gpio_en/enable").exists() ||
                Evo2UsbBoardController.hasEvo2Device(this)
            return evo2HardwareDetected
        }

    private val usesCompanionDisplayMode: Boolean
        get() = isChessnutClockDevice || isChessnutEvo2Device

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        evo2DisplayRotation = currentDisplayRotation()
        appUpdateManager = AppUpdateManagerFactory.create(this)
        keepCompanionDisplayReady()
        if (isChessnutEvo2Device) {
            evo2UsbPowerController()
            bindEvo2BoardService()
        }

        // 只有在棋钟设备上才启动 USB 服务
        if (isChessnutClockDevice) {
            startUsbClockService()
        } else {
        }

        captureWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetIntent(intent)
    }

    private fun startUsbClockService() {
        val intent = Intent(this, UsbClockService::class.java)
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    private fun bindEvo2BoardService() {
        if (evo2BoardBound || evo2BoardBinding) return
        evo2BoardBinding = bindService(
            Intent(this, Evo2BoardService::class.java),
            evo2BoardServiceConnection,
            Context.BIND_AUTO_CREATE
        )
    }

    private fun evo2UsbPowerController(): Evo2UsbPowerController {
        val existing = evo2UsbPowerController
        if (existing != null) return existing
        return Evo2UsbPowerController(this) { screenOff ->
            mainHandler.post {
                evo2PowerEventSink?.success(mapOf("screenOff" to screenOff))
            }
        }.also { controller ->
            controller.start()
            evo2UsbPowerController = controller
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(WakelockPlusPlugin::class.java)) {
            flutterEngine.plugins.add(WakelockPlusPlugin())
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            appLifecycleChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "moveToBackground") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            result.success(moveTaskToBack(true))
        }

        // 性能监控 Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            performanceChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "profile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            result.success(readPerformanceProfile())
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            evo2BoardMethodChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    if (!EVO2_DEVICE_DETECTION_ENABLED) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(
                        evo2BoardService?.isAvailable()
                            ?: Evo2UsbBoardController.hasEvo2Device(this)
                    )
                }
                "connect" -> {
                    evo2ConnectRequested = true
                    bindEvo2BoardService()
                    result.success(evo2BoardService?.connect() ?: false)
                }
                "disconnect" -> {
                    evo2ConnectRequested = false
                    evo2BoardService?.disconnect()
                    result.success(null)
                }
                "setLedRows" -> {
                    val rows = call.argument<ByteArray>("rows")
                    if (rows == null) {
                        result.error("invalid_rows", "EVO2 LED rows were empty.", null)
                        return@setMethodCallHandler
                    }
                    result.success(evo2BoardService?.setLedRows(rows) == true)
                }
                "setLedPatternPixels" -> {
                    val pixels = call.argument<ByteArray>("pixels")
                    if (pixels == null) {
                        result.error("invalid_pixels", "EVO2 LED pixels were empty.", null)
                        return@setMethodCallHandler
                    }
                    result.success(
                        evo2BoardService?.setLedPatternPixels(pixels) == true
                    )
                }
                "setLedBrightness" -> {
                    val brightness = call.argument<Int>("brightness")
                    if (brightness == null) {
                        result.error(
                            "invalid_brightness",
                            "EVO2 LED brightness was empty.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    result.success(
                        evo2BoardService?.setLedBrightness(brightness) == true
                    )
                }
                "clearLeds" -> {
                    result.success(evo2BoardService?.clearLeds() == true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            evo2BoardEventChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                evo2BoardEventSink = events
                bindEvo2BoardService()
                evo2BoardService?.setListener(evo2BoardListener)
            }

            override fun onCancel(arguments: Any?) {
                evo2BoardEventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            evo2PowerMethodChannel
        ).setMethodCallHandler { call, result ->
            if (!isChessnutEvo2Device) {
                result.success(false)
                return@setMethodCallHandler
            }
            val controller = evo2UsbPowerController()
            when (call.method) {
                "isScreenOff" -> result.success(controller.isScreenOff())
                "setUsbPower" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    result.success(controller.setUsbPower(enabled))
                }
                "setScreenOffPolicy" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    val gameActive =
                        call.argument<Boolean>("gameActive") == true
                    result.success(
                        controller.setScreenOffPolicy(enabled, gameActive)
                    )
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            evo2PowerEventChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                evo2PowerEventSink = events
                if (isChessnutEvo2Device) {
                    events?.success(
                        mapOf("screenOff" to evo2UsbPowerController().isScreenOff())
                    )
                }
            }

            override fun onCancel(arguments: Any?) {
                evo2PowerEventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            evo2DisplayMethodChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "setScreenOrientation") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (!isChessnutEvo2Device) {
                result.success(false)
                return@setMethodCallHandler
            }
            val displayRotation = when (call.argument<String>("orientation")) {
                "rotation0" -> Surface.ROTATION_0
                "rotation90" -> Surface.ROTATION_90
                "rotation180" -> Surface.ROTATION_180
                "rotation270" -> Surface.ROTATION_270
                else -> null
            }
            if (displayRotation == null) {
                result.error(
                    "invalid_orientation",
                    "Unknown EVO2 screen orientation.",
                    null
                )
                return@setMethodCallHandler
            }
            evo2LedDisplayRotation = displayRotation
            val ledRotationApplied =
                evo2BoardService?.setDisplayRotation(displayRotation) ?: true
            val systemRotationApplied = setEvo2SystemDisplayRotation(displayRotation)
            requestedOrientation = requestedOrientationFor(displayRotation)
            result.success(systemRotationApplied && ledRotationApplied)
        }

        // 棋盘后台连接 Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            boardBackgroundChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepAlive" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    val connected = call.argument<Boolean>("connected") == true
                    val boardName = call.argument<String>("boardName")
                        ?: "Chessnut board"
                    BoardBackgroundConnectionService.setKeepAlive(
                        this,
                        enabled && connected,
                        boardName
                    )
                    result.success(null)
                }
                "disconnectBoardHardware" -> {
                    BoardBackgroundConnectionService.stop(this)
                    UniversalBleShutdown.disconnectAll("dart requested board hardware disconnect")
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Stockfish 网络文件 Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            stockfishNetworkChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "prepare") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                result.success(prepareStockfishNetworks())
            } catch (error: Throwable) {
                result.error(
                    "stockfish_nnue_prepare_failed",
                    error.message ?: "Unable to prepare Stockfish NNUE files",
                    null
                )
            }
        }

        // USB 时钟 Method Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            clockMethodChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val connected = usbClockService?.connect() ?: false
                    result.success(connected)
                }
                "disconnect" -> {
                    usbClockService?.disconnect()
                    result.success(null)
                }
                "setActiveSide" -> {
                    val sideStr = call.argument<String>("side")
                    val side = when (sideStr) {
                        "LEFT" -> UsbClockService.ClockSide.LEFT
                        "RIGHT" -> UsbClockService.ClockSide.RIGHT
                        else -> {
                            result.error("INVALID_ARGUMENT", "Invalid side: $sideStr", null)
                            return@setMethodCallHandler
                        }
                    }
                    val success = usbClockService?.setActiveSide(side) ?: false
                    result.success(success)
                }
                "getLastButton" -> {
                    result.success(usbClockService?.getLastButton()?.name)
                }
                "getConnectionState" -> {
                    val state = usbClockService?.getConnectionState()?.name ?: "DISCONNECTED"
                    result.success(state)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // USB 时钟 Event Channel
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            clockEventChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                clockEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                clockEventSink = null
            }
        })

        // Home Widget Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            homeWidgetChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncSnapshot" -> {
                    @Suppress("UNCHECKED_CAST")
                    val values = call.arguments as? Map<String, Any?>
                    if (values == null) {
                        result.error("invalid_snapshot", "Widget snapshot was empty.", null)
                        return@setMethodCallHandler
                    }
                    HomeWidgetStore.writeSnapshot(this, values)
                    ChessnutHomeWidgetProvider.updateAll(this)
                    result.success(null)
                }
                "consumeLaunchAction" -> {
                    val action = pendingWidgetAction ?: HomeWidgetStore.consumeLaunchAction(this)
                    pendingWidgetAction = null
                    result.success(action)
                }
                "readVisionEnabled" -> {
                    result.success(HomeWidgetStore.readVisionEnabled(this))
                }
                "setVisionEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    HomeWidgetStore.writeVisionEnabled(this, enabled)
                    ChessnutHomeWidgetProvider.updateAll(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Android Accessibility + Vision bridge
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            accessibilityVisionChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setRecognitionStatus" -> {
                    VisionNotificationLanguage.setPreference(
                        this, call.argument<String>("languageTag") ?: "system"
                    )
                    VisionStatusNotification.update(
                        this,
                        enabled = call.argument<Boolean>("enabled") == true,
                        recognizing = call.argument<Boolean>("recognizing") == true,
                        boardConnected = call.argument<Boolean>("boardConnected") == true
                    )
                    requestVisionNotificationPermissionIfNeeded()
                    result.success(null)
                }
                "isAccessibilityRunning" -> {
                    result.success(ChessnutAccessibilityService.isRunning)
                }
                "openAccessibilitySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    } catch (error: Throwable) {
                        result.error(
                            "accessibility_settings_unavailable",
                            error.message ?: "Unable to open accessibility settings",
                            null
                        )
                    }
                }
                "recognizeScreenshot" -> {
                    recognizeAccessibilityScreenshot(result)
                }
                "dispatchMoveGesture" -> {
                    @Suppress("UNCHECKED_CAST")
                    val values = call.arguments as? Map<String, Any?>
                    dispatchMoveGesture(values, result)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            playInAppUpdateChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAvailability" -> {
                    checkPlayInAppUpdateAvailability(result)
                }
                "startUpdate" -> {
                    val immediate = call.argument<Boolean>("immediate") == true
                    startPlayInAppUpdate(immediate, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        activityResumed = true
        VisionStatusNotification.refresh(this)
        requestVisionNotificationPermissionIfNeeded()
        keepCompanionDisplayReady()
        if (isChessnutEvo2Device) {
            evo2UsbPowerController().onActivityResumed()
        }
    }

    override fun onPause() {
        activityResumed = false
        super.onPause()
    }

    private fun requestVisionNotificationPermissionIfNeeded() {
        if (!activityResumed || !VisionStatusNotification.enabled ||
            visionNotificationPermissionRequested ||
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) return
        visionNotificationPermissionRequested = true
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            visionNotificationPermissionRequestCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == visionNotificationPermissionRequestCode) {
            // Uses the latest state, so granting after switching Vision off
            // cannot resurrect an outdated notification.
            VisionStatusNotification.refresh(this)
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        VisionStatusNotification.refresh(this)
        val displayRotation = currentDisplayRotation()
        if (isChessnutEvo2Device && displayRotation != evo2DisplayRotation) {
            evo2DisplayRotation = displayRotation
            if (evo2LedDisplayRotation == null) {
                mainHandler.post { evo2BoardService?.refreshLedDisplay() }
            }
        }
    }

    override fun onDestroy() {
        VisionStatusNotification.clear(this)
        UniversalBleShutdown.disconnectAll("main activity destroyed")
        super.onDestroy()
        if (::appUpdateManager.isInitialized) {
            appUpdateManager.unregisterListener(appUpdateListener)
        }
        if (isBound) {
            unbindService(serviceConnection)
            isBound = false
        }
        if (evo2BoardBound || evo2BoardBinding) {
            evo2BoardService?.setListener(null)
            unbindService(evo2BoardServiceConnection)
            evo2BoardBound = false
            evo2BoardBinding = false
        }
        evo2BoardService = null
        evo2UsbPowerController?.dispose()
        evo2UsbPowerController = null
        clockEventSink = null
        evo2BoardEventSink = null
        evo2PowerEventSink = null
    }

    private fun keepCompanionDisplayReady() {
        if (isChessnutClockDevice) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        }
        if (usesCompanionDisplayMode) {
            wakeCompanionDisplay()
            hideSystemBars()
        }
    }

    @Suppress("DEPRECATION")
    private fun requestedOrientationFor(displayRotation: Int): Int {
        val currentRotation = currentDisplayRotation()
        val currentOrientation = resources.configuration.orientation
        val naturalPortrait = when (currentRotation) {
            Surface.ROTATION_0, Surface.ROTATION_180 ->
                currentOrientation == Configuration.ORIENTATION_PORTRAIT
            Surface.ROTATION_90, Surface.ROTATION_270 ->
                currentOrientation == Configuration.ORIENTATION_LANDSCAPE
            else -> true
        }
        return if (naturalPortrait) {
            when (displayRotation) {
                Surface.ROTATION_0 -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                Surface.ROTATION_90 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                Surface.ROTATION_180 ->
                    ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
                else -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
            }
        } else {
            when (displayRotation) {
                Surface.ROTATION_0 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                Surface.ROTATION_90 -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                Surface.ROTATION_180 ->
                    ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                else -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
            }
        }
    }

    private fun setEvo2SystemDisplayRotation(displayRotation: Int): Boolean {
        return try {
            val autoRotationDisabled = Settings.System.putInt(
                contentResolver,
                Settings.System.ACCELEROMETER_ROTATION,
                0
            )
            val userRotationApplied = Settings.System.putInt(
                contentResolver,
                Settings.System.USER_ROTATION,
                displayRotation
            )
            autoRotationDisabled && userRotationApplied
        } catch (_: SecurityException) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun currentDisplayRotation(): Int {
        return windowManager.defaultDisplay.rotation
    }

    private fun wakeCompanionDisplay() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setTurnScreenOn(true)
            setShowWhenLocked(true)
            val keyguardManager =
                getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    private fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
            return
        }

        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    private fun readPerformanceProfile(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return mapOf(
            "platform" to "android",
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "sdkInt" to Build.VERSION.SDK_INT,
            "osVersion" to Build.VERSION.RELEASE,
            "isLowRamDevice" to activityManager.isLowRamDevice,
            "memoryClassMb" to activityManager.memoryClass,
            "largeMemoryClassMb" to activityManager.largeMemoryClass,
            "totalRamMb" to (memoryInfo.totalMem / 1024L / 1024L).toInt(),
            "cpuCores" to Runtime.getRuntime().availableProcessors(),
            "isChessnutClock" to isChessnutClockDevice,
            "isChessnutEvo2" to isChessnutEvo2Device
        )
    }

    private fun startPlayInAppUpdate(immediate: Boolean, result: MethodChannel.Result) {
        val updateType = if (immediate) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { appUpdateInfo ->
                if (appUpdateInfo.updateAvailability() != UpdateAvailability.UPDATE_AVAILABLE) {
                    result.success("unavailable")
                    return@addOnSuccessListener
                }
                if (!appUpdateInfo.isUpdateTypeAllowed(updateType)) {
                    result.success("notAllowed")
                    return@addOnSuccessListener
                }
                try {
                    if (updateType == AppUpdateType.FLEXIBLE) {
                        appUpdateManager.registerListener(appUpdateListener)
                    }
                    appUpdateManager.startUpdateFlow(
                        appUpdateInfo,
                        this,
                        AppUpdateOptions.newBuilder(updateType).build()
                    ).addOnSuccessListener {
                        result.success("started")
                    }.addOnFailureListener { error ->
                        result.error(
                            "play_update_start_failed",
                            error.message ?: "Unable to start Google Play update",
                            null
                        )
                    }
                } catch (error: Throwable) {
                    result.error(
                        "play_update_start_failed",
                        error.message ?: "Unable to start Google Play update",
                        null
                    )
                }
            }
            .addOnFailureListener { error ->
                result.error(
                    "play_update_unavailable",
                    error.message ?: "Google Play update is unavailable",
                    null
                )
            }
    }

    private fun checkPlayInAppUpdateAvailability(result: MethodChannel.Result) {
        val installerPackageName = currentInstallerPackageName()
        if (installerPackageName != "com.android.vending") {
            result.success(mapOf(
                "available" to false,
                "immediateAllowed" to false,
                "flexibleAllowed" to false,
                "availableVersionCode" to 0,
                "installerPackageName" to installerPackageName,
                "installedFromGooglePlay" to false
            ))
            return
        }

        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { appUpdateInfo ->
                val available =
                    appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                result.success(mapOf(
                    "available" to available,
                    "immediateAllowed" to appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                    "flexibleAllowed" to appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                    "availableVersionCode" to appUpdateInfo.availableVersionCode(),
                    "installerPackageName" to installerPackageName,
                    "installedFromGooglePlay" to (installerPackageName == "com.android.vending")
                ))
            }
            .addOnFailureListener { error ->
                result.error(
                    "play_update_unavailable",
                    error.message ?: "Google Play update is unavailable",
                    null
                )
            }
    }

    private fun currentInstallerPackageName(): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                packageManager.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun captureWidgetIntent(intent: Intent?) {
        if (intent?.action != ChessnutHomeWidgetProvider.ACTION_WIDGET_LAUNCH) {
            return
        }
        val action = intent.getStringExtra("widgetAction") ?: "openApp"
        val values = mutableMapOf<String, Any?>("action" to action)
        pendingWidgetAction = values
        HomeWidgetStore.writeLaunchAction(this, values)
    }

    private fun prepareStockfishNetworks(): Map<String, String> {
        val targetDir = File(filesDir, "stockfish_nnue")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }
        val paths = stockfishNnueFiles.keys.associateWith { filename ->
            copyStockfishNetworkIfNeeded(filename, targetDir).absolutePath
        }
        return mapOf(
            "big" to requireNotNull(paths["nn-c288c895ea92.nnue"]),
            "small" to requireNotNull(paths["nn-37f18f62d772.nnue"])
        )
    }

    private fun copyStockfishNetworkIfNeeded(filename: String, targetDir: File): File {
        val target = File(targetDir, filename)
        val expectedSize = requireNotNull(stockfishNnueFiles[filename])
        if (target.exists() && target.length() == expectedSize) {
            return target
        }

        assets.open(filename).use { input ->
            FileOutputStream(target).use { output ->
                input.copyTo(output)
                output.fd.sync()
            }
        }
        if (target.length() != expectedSize) {
            throw IllegalStateException(
                "Unexpected Stockfish NNUE size for $filename: ${target.length()}"
            )
        }
        return target
    }

    private fun recognizeAccessibilityScreenshot(result: MethodChannel.Result) {
        BoardBackgroundConnectionService.captureAndRecognize { serviceResult ->
            val json = serviceResult.json
            if (json != null) {
                result.success(json)
            } else {
                result.error(
                    serviceResult.errorCode ?: "vision_recognition_failed",
                    serviceResult.errorMessage ?: "Unable to recognize the screenshot.",
                    serviceResult.errorDetails
                )
            }
        }
    }

    private fun dispatchMoveGesture(values: Map<String, Any?>?, result: MethodChannel.Result) {
        val service = ChessnutAccessibilityService.instance
        if (!ChessnutAccessibilityService.isRunning || service == null) {
            result.error(
                "accessibility_not_running",
                "Chessnut Vision accessibility service is not running.",
                null
            )
            return
        }
        if (values == null) {
            result.error("invalid_gesture", "Gesture arguments were empty.", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val from = values["from"] as? Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val to = values["to"] as? Map<String, Any?>
        val fromPoint = rectCenter(from)
        if (fromPoint == null) {
            result.error("invalid_gesture", "Gesture source rectangle is invalid.", null)
            return
        }
        val toPoint = rectCenter(to)
        try {
            val builder = GestureDescription.Builder()
            val tapDurationMs = 140L
            if (toPoint == null) {
                val path = Path().apply {
                    moveTo(fromPoint.first, fromPoint.second)
                }
                builder.addStroke(
                    GestureDescription.StrokeDescription(
                        path,
                        0L,
                        tapDurationMs,
                        false
                    )
                )
            } else {
                val secondTapDelayMs = 200L
                val fromPath = Path().apply {
                    moveTo(fromPoint.first, fromPoint.second)
                }
                val toPath = Path().apply {
                    moveTo(toPoint.first, toPoint.second)
                }
                builder.addStroke(
                    GestureDescription.StrokeDescription(
                        fromPath,
                        0L,
                        tapDurationMs,
                        false
                    )
                )
                builder.addStroke(
                    GestureDescription.StrokeDescription(
                        toPath,
                        secondTapDelayMs,
                        tapDurationMs,
                        false
                    )
                )
            }
            service.dispatchGesture(
                builder.build(),
                object : AccessibilityService.GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        super.onCompleted(gestureDescription)
                        mainHandler.post { result.success(true) }
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        super.onCancelled(gestureDescription)
                        mainHandler.post { result.success(false) }
                    }
                },
                mainHandler
            )
        } catch (error: Throwable) {
            result.error(
                "accessibility_gesture_failed",
                error.message ?: "Unable to dispatch accessibility gesture",
                null
            )
        }
    }

    private fun rectCenter(rect: Map<String, Any?>?): Pair<Float, Float>? {
        if (rect == null) return null
        val left = numeric(rect["left"]) ?: return null
        val top = numeric(rect["top"]) ?: return null
        val width = numeric(rect["width"]) ?: return null
        val height = numeric(rect["height"]) ?: return null
        if (width <= 0.0 || height <= 0.0) return null
        return Pair((left + width / 2.0).toFloat(), (top + height / 2.0).toFloat())
    }

    private fun numeric(value: Any?): Double? {
        return when (value) {
            is Double -> value
            is Float -> value.toDouble()
            is Int -> value.toDouble()
            is Long -> value.toDouble()
            is Number -> value.toDouble()
            else -> null
        }
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val EVO2_DEVICE_DETECTION_ENABLED = false
    }
}
