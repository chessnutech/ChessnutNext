package com.chessnut.chessnutnext

import android.accessibilityservice.AccessibilityService
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Display
import com.navideck.universal_ble.UniversalBleShutdown
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class BoardBackgroundConnectionService : Service() {
    private val screenshotExecutor: ExecutorService = Executors.newSingleThreadExecutor {
        runnable -> Thread(runnable, "chessnut-vision-screenshot")
    }
    private val inferenceExecutor: ExecutorService = Executors.newSingleThreadExecutor {
        runnable -> Thread(runnable, "chessnut-vision-inference")
    }
    private val visionBusy = AtomicBoolean(false)
    @Volatile private var keepAliveRequested = false

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val boardName = intent?.getStringExtra(EXTRA_BOARD_NAME)
            ?: "Chessnut board"
        if (intent != null) {
            keepAliveRequested = intent.getBooleanExtra(EXTRA_KEEP_ALIVE, true)
        }
        ensureNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification(boardName),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification(boardName))
        }
        return if (keepAliveRequested) START_STICKY else START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        VisionStatusNotification.clear(this)
        if (!keepAliveRequested) {
            UniversalBleShutdown.disconnectAll("board background task removed")
            stopSelf()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        screenshotExecutor.shutdownNow()
        inferenceExecutor.shutdownNow()
        visionBusy.set(false)
        super.onDestroy()
    }

    fun captureAndRecognize(callback: (VisionServiceResult) -> Unit) {
        if (!visionBusy.compareAndSet(false, true)) {
            callback(VisionServiceResult.error("vision_busy", "Vision recognition is already running."))
            return
        }
        try {
            inferenceExecutor.execute {
                try {
                    NativeVision.initialize(applicationContext)
                } catch (_: Throwable) {
                }
            }
        } catch (error: Throwable) {
            visionBusy.set(false)
            callback(VisionServiceResult.error(
                "vision_service_unavailable",
                error.message ?: "The Vision service is stopping."
            ))
            return
        }
        captureScreenshot { screenshot, captureError ->
            if (screenshot == null) {
                visionBusy.set(false)
                callback(captureError ?: VisionServiceResult.error(
                    "accessibility_screenshot_failed",
                    "Unable to take accessibility screenshot."
                ))
                return@captureScreenshot
            }
            try {
                inferenceExecutor.execute {
                    try {
                        val json = NativeVision.detectArgbJson(
                            applicationContext,
                            screenshot.argbPixels,
                            screenshot.width,
                            screenshot.height
                        )?.trim()
                        if (json.isNullOrEmpty()) {
                            callback(VisionServiceResult.error(
                                "vision_empty_result",
                                "Vision recognition returned no result."
                            ))
                        } else {
                            callback(VisionServiceResult.success(json))
                        }
                    } catch (error: Throwable) {
                        callback(VisionServiceResult.error(
                            "vision_recognition_failed",
                            error.message ?: "Unable to recognize the screenshot."
                        ))
                    } finally {
                        visionBusy.set(false)
                    }
                }
            } catch (error: Throwable) {
                visionBusy.set(false)
                callback(VisionServiceResult.error(
                    "vision_service_unavailable",
                    error.message ?: "The Vision service is stopping."
                ))
            }
        }
    }

    private fun captureScreenshot(
        callback: (VisionScreenshot?, VisionServiceResult?) -> Unit
    ) {
        val completed = AtomicBoolean(false)
        val timeout = Runnable {
            if (completed.compareAndSet(false, true)) {
                callback(null, VisionServiceResult.error(
                    "accessibility_screenshot_timeout",
                    "Accessibility screenshot did not return in time."
                ))
            }
        }

        fun finish(screenshot: VisionScreenshot?, error: VisionServiceResult?) {
            if (!completed.compareAndSet(false, true)) {
                return
            }
            mainHandler.removeCallbacks(timeout)
            callback(screenshot, error)
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            finish(null, VisionServiceResult.error(
                "accessibility_screenshot_unsupported",
                "Android 11 or newer is required for accessibility screenshots."
            ))
            return
        }
        val accessibility = ChessnutAccessibilityService.instance
        if (!ChessnutAccessibilityService.isRunning || accessibility == null) {
            finish(null, VisionServiceResult.error(
                "accessibility_not_running",
                "Chessnut Vision accessibility service is not running."
            ))
            return
        }
        try {
            mainHandler.postDelayed(timeout, SCREENSHOT_TIMEOUT_MS)
            accessibility.takeScreenshot(
                Display.DEFAULT_DISPLAY,
                screenshotExecutor,
                object : AccessibilityService.TakeScreenshotCallback {
                    override fun onFailure(errorCode: Int) {
                        finish(null, VisionServiceResult.error(
                            "accessibility_screenshot_failed",
                            "Accessibility screenshot failed: $errorCode",
                            mapOf("errorCode" to errorCode)
                        ))
                    }

                    override fun onSuccess(screenshot: AccessibilityService.ScreenshotResult) {
                        try {
                            val bitmap = Bitmap.wrapHardwareBuffer(
                                screenshot.hardwareBuffer,
                                screenshot.colorSpace
                            )
                            if (bitmap == null) {
                                finish(null, VisionServiceResult.error(
                                    "accessibility_screenshot_empty",
                                    "Accessibility screenshot returned an empty bitmap."
                                ))
                                return
                            }
                            val softwareBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, false)
                            if (softwareBitmap == null) {
                                finish(null, VisionServiceResult.error(
                                    "accessibility_screenshot_pixel_copy_failed",
                                    "Unable to copy accessibility screenshot pixels."
                                ))
                                return
                            }
                            try {
                                val width = softwareBitmap.width
                                val height = softwareBitmap.height
                                val pixels = IntArray(width * height)
                                softwareBitmap.getPixels(
                                    pixels,
                                    0,
                                    width,
                                    0,
                                    0,
                                    width,
                                    height
                                )
                                finish(VisionScreenshot(pixels, width, height), null)
                            } finally {
                                softwareBitmap.recycle()
                            }
                        } catch (error: Throwable) {
                            finish(null, VisionServiceResult.error(
                                "accessibility_screenshot_pixel_copy_failed",
                                error.message ?: "Unable to copy accessibility screenshot pixels."
                            ))
                        } finally {
                            try {
                                screenshot.hardwareBuffer.close()
                            } catch (_: Throwable) {
                            }
                        }
                    }
                }
            )
        } catch (error: Throwable) {
            mainHandler.removeCallbacks(timeout)
            finish(null, VisionServiceResult.error(
                "accessibility_screenshot_failed",
                error.message ?: "Unable to take accessibility screenshot."
            ))
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Board connection",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps your Chessnut board connected while the app is in the background."
        }
        manager.createNotificationChannel(channel)
    }

    private fun notification(boardName: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("$boardName connected")
            .setContentText("Keeping the board ready while the screen is off.")
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "chessnut_board_connection"
        private const val NOTIFICATION_ID = 3001
        private const val EXTRA_BOARD_NAME = "boardName"
        private const val EXTRA_KEEP_ALIVE = "keepAlive"
        private const val SCREENSHOT_TIMEOUT_MS = 2000L

        @Volatile
        private var instance: BoardBackgroundConnectionService? = null

        private val mainHandler = Handler(Looper.getMainLooper())

        fun captureAndRecognize(callback: (VisionServiceResult) -> Unit) {
            val service = instance
            if (service == null) {
                mainHandler.post {
                    callback(VisionServiceResult.error(
                        "vision_service_not_running",
                        "The board background service is not running."
                    ))
                }
                return
            }
            service.captureAndRecognize { serviceResult ->
                mainHandler.post { callback(serviceResult) }
            }
        }

        fun setKeepAlive(context: Context, enabled: Boolean, boardName: String) {
            if (!enabled) {
                stop(context)
                return
            }
            try {
                val intent = Intent(context, BoardBackgroundConnectionService::class.java)
                    .putExtra(EXTRA_BOARD_NAME, boardName)
                    .putExtra(EXTRA_KEEP_ALIVE, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Throwable) {
            }
        }

        fun start(context: Context, boardName: String) {
            setKeepAlive(context, true, boardName)
        }

        fun stop(context: Context) {
            context.stopService(
                Intent(context, BoardBackgroundConnectionService::class.java)
            )
        }
    }
}

data class VisionServiceResult(
    val json: String? = null,
    val errorCode: String? = null,
    val errorMessage: String? = null,
    val errorDetails: Any? = null
) {
    companion object {
        fun success(json: String) = VisionServiceResult(json = json)

        fun error(code: String, message: String, details: Any? = null) =
            VisionServiceResult(
                errorCode = code,
                errorMessage = message,
                errorDetails = details
            )
    }
}

private object NativeVision {
    private const val BACKEND_A733_NPU = 1
    private const val DETECT_PASS_SINGLE = 1
    private const val DETECT_PASS_DOUBLE = 2

    init {
        System.loadLibrary("vision")
    }

    @Volatile
    private var initialized = false

    @Synchronized
    fun initialize(context: Context) {
        if (initialized) return
        yolov5ncnnInit()
        if (isChessnutClockDevice()) {
            yolov5ncnnSetBackend(
                BACKEND_A733_NPU,
                context.cacheDir.absolutePath
            )
        }
        initialized = true
    }

    fun detectArgbJson(
        context: Context,
        pixels: IntArray,
        width: Int,
        height: Int
    ): String? {
        initialize(context)
        val passCount = if (isChessnutClockDevice()) {
            DETECT_PASS_DOUBLE
        } else {
            DETECT_PASS_SINGLE
        }
        return yolov5ncnnDetectArgbJsonWithPasses(
            pixels,
            width,
            height,
            passCount
        )
    }

    private fun isChessnutClockDevice(): Boolean {
        return Build.MODEL.equals("Chessnut_Companion", ignoreCase = true) &&
            Build.MANUFACTURER.equals("Chessnut", ignoreCase = true)
    }

    private external fun yolov5ncnnDetectArgbJsonWithPasses(
        pixels: IntArray,
        width: Int,
        height: Int,
        passCount: Int
    ): String?

    private external fun yolov5ncnnInit(): Int

    private external fun yolov5ncnnSetBackend(backend: Int, modelDir: String): Int
}

private data class VisionScreenshot(
    val argbPixels: IntArray,
    val width: Int,
    val height: Int
)
