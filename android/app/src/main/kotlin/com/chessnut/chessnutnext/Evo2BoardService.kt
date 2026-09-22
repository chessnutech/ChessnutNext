package com.chessnut.chessnutnext

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.RemoteCallbackList
import com.chessnut.chessnutnext.evo2.IEvo2BoardListener
import com.chessnut.chessnutnext.evo2.IEvo2BoardService

class Evo2BoardService : Service(), Evo2UsbBoardController.Listener {
    interface Listener {
        fun onConnectionStateChanged(state: Evo2UsbBoardController.ConnectionState)
        fun onFenChanged(fen: String, rawPayload: ByteArray)
        fun onResponse(payload: ByteArray)
        fun onError(error: String)
    }

    inner class LocalBinder : Binder() {
        fun getService(): Evo2BoardService = this@Evo2BoardService
    }

    private val localBinder = LocalBinder()
    private val remoteCallbacks = RemoteCallbackList<IEvo2BoardListener>()
    private val operationLock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var controller: Evo2UsbBoardController
    private var localListener: Listener? = null
    @Volatile private var aidlClientBound = false
    @Volatile private var latestFen: String? = null
    @Volatile private var latestFenPayload: ByteArray? = null

    private val reconnectRunnable = Runnable {
        if (!aidlClientBound) return@Runnable
        if (ensureConnected()) {
            enableRealtimeFen()
        } else {
            scheduleReconnect()
        }
    }

    private val aidlBinder = object : IEvo2BoardService.Stub() {
        override fun registerListener(listener: IEvo2BoardListener?) {
            if (listener == null) return
            remoteCallbacks.register(listener)
            try {
                listener.onConnectionStateChanged(connectionState().ordinal)
                val fen = this@Evo2BoardService.latestFen
                val payload = this@Evo2BoardService.latestFenPayload
                if (fen != null && payload != null) {
                    listener.onFenChanged(fen, payload.copyOf())
                }
            } catch (_: Throwable) {
            }
            ensureAidlReady()
        }

        override fun unregisterListener(listener: IEvo2BoardListener?) {
            if (listener != null) remoteCallbacks.unregister(listener)
        }

        override fun getLatestFen(): String {
            ensureAidlReady()
            return this@Evo2BoardService.latestFen.orEmpty()
        }

        override fun getLatestFenPayload(): ByteArray {
            ensureAidlReady()
            return this@Evo2BoardService.latestFenPayload?.copyOf()
                ?: ByteArray(0)
        }

        override fun requestFen(): Boolean = runAidlOperation {
            controller.writeBoard(REALTIME_FEN_COMMAND)
        }

        override fun setLedRows(rows: ByteArray?): Boolean =
            rows != null && rows.size >= 8 && runAidlOperation {
                controller.setLedRows(rows)
            }

        override fun setLedPatternPixels(pixels: ByteArray?): Boolean =
            pixels != null && pixels.size == LED_PATTERN_BYTES && runAidlOperation {
                controller.setLedPatternPixels(pixels)
            }

        override fun clearLeds(): Boolean = runAidlOperation {
            controller.clearLeds()
        }

        override fun writeLedCommand(command: ByteArray?): Boolean =
            command != null && command.isNotEmpty() && runAidlOperation {
                controller.writeLedCommand(command)
            }

        override fun writeBoardCommand(command: ByteArray?): Boolean =
            command != null && command.isNotEmpty() && runAidlOperation {
                controller.writeBoard(command)
            }
    }

    override fun onCreate() {
        super.onCreate()
        controller = Evo2UsbBoardController(this)
        controller.setListener(this)
    }

    override fun onBind(intent: Intent?): IBinder {
        if (intent?.action == ACTION_BIND_AIDL) {
            aidlClientBound = true
            ensureAidlReady()
            return aidlBinder
        }
        return localBinder
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (intent?.action == ACTION_BIND_AIDL) {
            aidlClientBound = false
            mainHandler.removeCallbacks(reconnectRunnable)
        }
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(reconnectRunnable)
        controller.dispose()
        remoteCallbacks.kill()
        localListener = null
        super.onDestroy()
    }

    fun setListener(listener: Listener?) {
        localListener = listener
        listener?.onConnectionStateChanged(connectionState())
        val fen = latestFen
        val payload = latestFenPayload
        if (listener != null && fen != null && payload != null) {
            listener.onFenChanged(fen, payload.copyOf())
        }
    }

    fun isAvailable(): Boolean = controller.isAvailable()

    fun connectionState(): Evo2UsbBoardController.ConnectionState =
        controller.getConnectionState()

    fun connect(): Boolean = synchronized(operationLock) {
        controller.connect()
    }

    fun disconnect() = synchronized(operationLock) {
        controller.disconnect()
    }

    fun requestFen(): Boolean = synchronized(operationLock) {
        controller.writeBoard(REALTIME_FEN_COMMAND)
    }

    fun setLedRows(rows: ByteArray): Boolean = synchronized(operationLock) {
        controller.setLedRows(rows)
    }

    fun setLedPatternPixels(pixels: ByteArray): Boolean = synchronized(operationLock) {
        controller.setLedPatternPixels(pixels)
    }

    fun setLedBrightness(brightness: Int): Boolean = synchronized(operationLock) {
        controller.setLedBrightness(brightness)
    }

    fun setDisplayRotation(rotation: Int): Boolean = synchronized(operationLock) {
        controller.setDisplayRotation(rotation)
    }

    fun refreshLedDisplay(): Boolean = synchronized(operationLock) {
        controller.refreshLedDisplay()
    }

    fun clearLeds(): Boolean = synchronized(operationLock) {
        controller.clearLeds()
    }

    fun writeLedCommand(command: ByteArray): Boolean = synchronized(operationLock) {
        controller.writeLedCommand(command)
    }

    fun writeBoardCommand(command: ByteArray): Boolean = synchronized(operationLock) {
        controller.writeBoard(command)
    }

    override fun onConnectionStateChanged(state: Evo2UsbBoardController.ConnectionState) {
        localListener?.onConnectionStateChanged(state)
        broadcast { it.onConnectionStateChanged(state.ordinal) }
        if (!aidlClientBound) return
        if (state == Evo2UsbBoardController.ConnectionState.CONNECTED) {
            mainHandler.removeCallbacks(reconnectRunnable)
            enableRealtimeFen()
        } else if (state == Evo2UsbBoardController.ConnectionState.DISCONNECTED) {
            scheduleReconnect()
        }
    }

    override fun onFenPayload(payload: ByteArray) {
        val fen = Evo2FenCodec.tryDecode(payload)
        localListener?.onFenChanged(fen.orEmpty(), payload.copyOf())
        if (fen == null) return
        latestFen = fen
        latestFenPayload = payload.copyOf()
        broadcast { it.onFenChanged(fen, payload.copyOf()) }
    }

    override fun onResponse(payload: ByteArray) {
        localListener?.onResponse(payload.copyOf())
        broadcast { it.onResponse(payload.copyOf()) }
    }

    override fun onError(error: String) {
        localListener?.onError(error)
        broadcast { it.onError(error) }
    }

    private inline fun broadcast(block: (IEvo2BoardListener) -> Unit) {
        val count = remoteCallbacks.beginBroadcast()
        try {
            for (index in 0 until count) {
                try {
                    block(remoteCallbacks.getBroadcastItem(index))
                } catch (_: Throwable) {
                }
            }
        } finally {
            remoteCallbacks.finishBroadcast()
        }
    }

    private fun ensureAidlReady() {
        if (ensureConnected()) {
            enableRealtimeFen()
        } else {
            scheduleReconnect()
        }
    }

    private fun ensureConnected(): Boolean = synchronized(operationLock) {
        if (controller.getConnectionState() ==
            Evo2UsbBoardController.ConnectionState.CONNECTED
        ) {
            return@synchronized true
        }
        controller.connect()
    }

    private fun enableRealtimeFen(): Boolean = synchronized(operationLock) {
        controller.writeBoard(REALTIME_FEN_COMMAND)
    }

    private fun runAidlOperation(operation: () -> Boolean): Boolean =
        synchronized(operationLock) {
            if (controller.getConnectionState() !=
                Evo2UsbBoardController.ConnectionState.CONNECTED &&
                !controller.connect()
            ) {
                scheduleReconnect()
                return@synchronized false
            }
            if (operation()) return@synchronized true

            controller.disconnect()
            if (!controller.connect()) {
                scheduleReconnect()
                return@synchronized false
            }
            operation().also { succeeded ->
                if (!succeeded) scheduleReconnect()
            }
        }

    private fun scheduleReconnect() {
        if (!aidlClientBound) return
        mainHandler.removeCallbacks(reconnectRunnable)
        mainHandler.postDelayed(reconnectRunnable, RECONNECT_DELAY_MS)
    }

    companion object {
        const val ACTION_BIND_AIDL =
            "com.chessnut.chessnutnext.evo2.Evo2BoardService"
        private const val LED_PATTERN_BYTES = 64 * 7 * 7 * 3
        private const val RECONNECT_DELAY_MS = 2_000L
        private val REALTIME_FEN_COMMAND = byteArrayOf(0x21, 0x01, 0x00)
    }
}
