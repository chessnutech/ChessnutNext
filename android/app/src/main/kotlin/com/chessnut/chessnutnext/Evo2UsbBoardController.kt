package com.chessnut.chessnutnext

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.WindowManager
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class Evo2UsbBoardController(private val context: Context) {
    companion object {
        private const val VENDOR_ID = 0x2d80
        private const val BOARD_PRODUCT_ID = 0x8700
        private const val LED_PRODUCT_ID = 0x6666
        private const val BOARD_INTERFACE_NUMBER = 0
        private const val ACTION_USB_PERMISSION =
            "com.chessnut.chessnutnext.EVO2_USB_PERMISSION"
        private const val READ_TIMEOUT_MS = 50
        private const val WRITE_TIMEOUT_MS = 1000

        private const val LED_ORIGIN_X = 4
        private const val LED_ORIGIN_Y = 4
        private const val LED_SQUARE_SIZE = 7
        private const val LED_SQUARE_R = 255
        private const val LED_SQUARE_G = 255
        private const val LED_SQUARE_B = 255
        private const val CMD_FILL_SCREEN = 0x01
        private const val CMD_FILL_RECT = 0x02
        private const val CMD_REGION_BEGIN = 0x20
        private const val CMD_REGION_DATA = 0x21
        private const val CMD_REGION_END = 0x22
        private const val LED_BOARD_SQUARE_COUNT = 64
        private const val LED_PATTERN_CELL_COUNT = LED_SQUARE_SIZE * LED_SQUARE_SIZE
        private const val LED_PATTERN_BYTES = LED_BOARD_SQUARE_COUNT * LED_PATTERN_CELL_COUNT * 3
        private const val LED_STREAM_MAX_PIXELS_PER_PACKET = 29
        private const val LED_FULL_REGION_UPDATE_THRESHOLD_SQUARES = 3
        private const val LED_BOARD_REGION_X = LED_ORIGIN_X
        private const val LED_BOARD_REGION_Y = LED_ORIGIN_Y
        private const val LED_BOARD_REGION_SIZE = LED_SQUARE_SIZE * 8

        fun hasEvo2Device(context: Context): Boolean {
            val usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
                ?: return false
            return usbManager.deviceList.values.any { isEvo2LedDevice(it) || hasEvo2Name(it) }
        }

        private fun isEvo2BoardDevice(device: UsbDevice): Boolean {
            return device.vendorId == VENDOR_ID && device.productId == BOARD_PRODUCT_ID
        }

        private fun isEvo2LedDevice(device: UsbDevice): Boolean {
            return device.vendorId == VENDOR_ID && device.productId == LED_PRODUCT_ID
        }

        private fun isEvo2UsbDevice(device: UsbDevice): Boolean {
            return isEvo2BoardDevice(device) || isEvo2LedDevice(device) || hasEvo2Name(device)
        }

        private fun hasEvo2Name(device: UsbDevice): Boolean {
            val product = device.productName.orEmpty().lowercase()
            val manufacturer = device.manufacturerName.orEmpty().lowercase()
            return product.contains("evo2") || manufacturer.contains("evo2")
        }
    }

    enum class ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED
    }

    interface Listener {
        fun onConnectionStateChanged(state: ConnectionState)
        fun onFenPayload(payload: ByteArray)
        fun onResponse(payload: ByteArray)
        fun onError(error: String)
    }

    private val appContext = context.applicationContext
    private var ledBrightness = 100
    private val usbManager = appContext.getSystemService(Context.USB_SERVICE) as UsbManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)
    private val lock = Any()

    private var listener: Listener? = null
    private var boardDevice: UsbDevice? = null
    private var boardConnection: UsbDeviceConnection? = null
    private var boardInterface: UsbInterface? = null
    private var boardReadEndpoint: UsbEndpoint? = null
    private var boardWriteEndpoint: UsbEndpoint? = null
    private var ledDevice: UsbDevice? = null
    private var ledConnection: UsbDeviceConnection? = null
    private var ledInterface: UsbInterface? = null
    private var ledWriteEndpoint: UsbEndpoint? = null
    private var ledRows: ByteArray? = null
    private var ledPatternPixels: ByteArray? = null
    private var ledPatternRotation: Int? = null
    private var displayRotationOverride: Int? = null
    private var ledStreamSeq: Int = 0
    private var readThread: Thread? = null
    private var receiverRegistered = false
    @Volatile private var state = ConnectionState.DISCONNECTED

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_USB_PERMISSION -> {
                    val device = intent.evo2UsbDeviceExtra()
                    val granted = intent.getBooleanExtra(
                        UsbManager.EXTRA_PERMISSION_GRANTED,
                        false
                    )
                    if (granted && device != null && isEvo2UsbDevice(device)) {
                        connect()
                    } else {
                        setState(ConnectionState.DISCONNECTED)
                        emitError("EVO2 USB permission denied")
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device = intent.evo2UsbDeviceExtra()
                    if (device != null && isEvo2UsbDevice(device)) {
                        connect()
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = intent.evo2UsbDeviceExtra() ?: return
                    if (device.deviceName == boardDevice?.deviceName) {
                        closeBoard()
                    }
                    if (device.deviceName == ledDevice?.deviceName) {
                        closeLed()
                    }
                    refreshConnectionState()
                }
            }
        }
    }

    fun setListener(listener: Listener?) {
        this.listener = listener
        listener?.onConnectionStateChanged(state)
    }

    fun getConnectionState(): ConnectionState = state

    fun isAvailable(): Boolean {
        return findBoardDevice() != null || findLedDevice() != null
    }

    fun connect(): Boolean {
        registerReceiver()
        val board = findBoardDevice()
        val led = findLedDevice()
        if (board == null && led == null) {
            setState(ConnectionState.DISCONNECTED)
            return false
        }

        val missingPermissionDevice = listOfNotNull(board, led)
            .firstOrNull { !usbManager.hasPermission(it) }
        if (missingPermissionDevice != null) {
            setState(ConnectionState.CONNECTING)
            requestPermission(missingPermissionDevice)
            return false
        }

        setState(ConnectionState.CONNECTING)
        if (board != null && boardConnection == null) {
            openBoard(board)
        }
        if (led != null && ledConnection == null) {
            openLed(led)
        }
        refreshConnectionState()
        return state == ConnectionState.CONNECTED
    }

    fun disconnect() {
        closeBoard()
        closeLed()
        setState(ConnectionState.DISCONNECTED)
    }

    fun dispose() {
        disconnect()
        unregisterReceiver()
        listener = null
    }

    fun setLedRows(rows: ByteArray): Boolean {
        if (rows.size < 8) return false
        if (ledConnection == null && findLedDevice() != null) {
            connect()
        }
        if (ledConnection == null) return false

        val nextRows = rows.copyOfRange(0, 8)
        val previousRows = ledRows
        var ok = true
        if (previousRows == null) {
            ok = fillScreen(0, 0, 0)
        }
        for (row in 0 until 8) {
            val previousRowByte = previousRows?.get(row)?.toInt()?.and(0xff) ?: 0
            val nextRowByte = nextRows[row].toInt() and 0xff
            val changedBits = if (previousRows == null) nextRowByte else previousRowByte xor nextRowByte
            for (col in 0 until 8) {
                val bit = 1 shl (7 - col)
                if ((changedBits and bit) == 0) continue
                val isLit = (nextRowByte and bit) != 0
                val x = LED_ORIGIN_X + col * LED_SQUARE_SIZE
                val y = LED_ORIGIN_Y + row * LED_SQUARE_SIZE
                ok = fillRect(
                    x,
                    y,
                    LED_SQUARE_SIZE,
                    LED_SQUARE_SIZE,
                    if (isLit) LED_SQUARE_R else 0,
                    if (isLit) LED_SQUARE_G else 0,
                    if (isLit) LED_SQUARE_B else 0
                ) && ok
            }
        }
        if (ok) {
            ledRows = nextRows
            ledPatternPixels = null
            ledPatternRotation = null
        }
        return ok
    }

    fun setLedPatternPixels(pixels: ByteArray): Boolean {
        if (pixels.size != LED_PATTERN_BYTES) return false
        if (ledConnection == null && findLedDevice() != null) {
            connect()
        }
        if (ledConnection == null) return false

        val previous = ledPatternPixels
        val next = pixels.copyOf()
        val rotation = currentDisplayRotation()
        val rotationChanged = previous != null && ledPatternRotation != rotation
        var ok = true
        if (previous == null) {
            ok = fillScreen(0, 0, 0)
        }
        val changedSquares = if (rotationChanged) {
            (0 until LED_BOARD_SQUARE_COUNT).toList()
        } else {
            changedPatternSquares(previous, next)
        }
        if (ok && changedSquares.size >= LED_FULL_REGION_UPDATE_THRESHOLD_SQUARES) {
            ok = writePatternRegion(next, rotation)
            if (ok) {
                ledPatternPixels = next
                ledPatternRotation = rotation
                ledRows = null
            }
            return ok
        }
        for (square in changedSquares) {
            ok = writePatternSquareRegion(next, square, rotation) && ok
        }
        if (ok) {
            ledPatternPixels = next
            ledPatternRotation = rotation
            ledRows = null
        }
        return ok
    }

    fun setLedBrightness(brightness: Int): Boolean {
        val next = brightness.coerceIn(0, 100)
        if (next == ledBrightness) return true
        val previous = ledBrightness
        ledBrightness = next
        val ok = refreshLedDisplay()
        if (!ok) ledBrightness = previous
        return ok
    }

    fun setDisplayRotation(rotation: Int): Boolean {
        if (rotation !in Surface.ROTATION_0..Surface.ROTATION_270) return false
        if (displayRotationOverride == rotation) return true
        displayRotationOverride = rotation
        return if (ledPatternPixels == null) true else refreshLedDisplay()
    }

    fun refreshLedDisplay(): Boolean {
        val pattern = ledPatternPixels
        if (pattern != null) {
            val rotation = currentDisplayRotation()
            val ok = writePatternRegion(pattern, rotation)
            if (ok) ledPatternRotation = rotation
            return ok
        }
        val rows = ledRows ?: return true
        ledRows = null
        return setLedRows(rows)
    }

    fun clearLeds(): Boolean {
        val ok = fillScreen(0, 0, 0)
        if (ok) {
            ledRows = ByteArray(8)
            ledPatternPixels = ByteArray(LED_PATTERN_BYTES)
            ledPatternRotation = currentDisplayRotation()
        }
        return ok
    }

    fun writeBoard(data: ByteArray): Boolean {
        synchronized(lock) {
            val connection = boardConnection ?: return false
            val endpoint = boardWriteEndpoint ?: return false
            val written = try {
                connection.bulkTransfer(endpoint, data, data.size, WRITE_TIMEOUT_MS)
            } catch (_: Throwable) {
                -1
            }
            return written == data.size
        }
    }

    fun writeLedCommand(data: ByteArray): Boolean {
        val ok = writeLedPayload(data)
        if (ok) {
            ledRows = null
            ledPatternPixels = null
            ledPatternRotation = null
        }
        return ok
    }

    private fun openBoard(device: UsbDevice): Boolean {
        val usbInterface = findBoardInterface(device)
        if (usbInterface == null) {
            emitError("EVO2 board USB interface not found")
            return false
        }
        val input = findEndpoint(usbInterface, UsbConstants.USB_DIR_IN)
        val output = findEndpoint(usbInterface, UsbConstants.USB_DIR_OUT)
        if (input == null) {
            emitError("EVO2 board USB input endpoint not found")
            return false
        }

        val connection = try {
            usbManager.openDevice(device)
        } catch (_: SecurityException) {
            null
        }
        if (connection == null) {
            emitError("Unable to open EVO2 board USB device")
            return false
        }
        if (!connection.claimInterface(usbInterface, true)) {
            connection.close()
            emitError("Unable to claim EVO2 board USB interface")
            return false
        }

        synchronized(lock) {
            boardDevice = device
            boardConnection = connection
            boardInterface = usbInterface
            boardReadEndpoint = input
            boardWriteEndpoint = output
        }
        startReadThread()
        return true
    }

    private fun openLed(device: UsbDevice): Boolean {
        val usbInterface = findLedInterface(device)
        if (usbInterface == null) {
            emitError("EVO2 LED USB interface not found")
            return false
        }
        val output = findEndpoint(usbInterface, UsbConstants.USB_DIR_OUT)
        if (output == null) {
            emitError("EVO2 LED USB output endpoint not found")
            return false
        }

        val connection = try {
            usbManager.openDevice(device)
        } catch (_: SecurityException) {
            null
        }
        if (connection == null) {
            emitError("Unable to open EVO2 LED USB device")
            return false
        }
        if (!connection.claimInterface(usbInterface, true)) {
            connection.close()
            emitError("Unable to claim EVO2 LED USB interface")
            return false
        }

        synchronized(lock) {
            ledDevice = device
            ledConnection = connection
            ledInterface = usbInterface
            ledWriteEndpoint = output
        }
        return true
    }

    private fun startReadThread() {
        running.set(false)
        readThread?.interrupt()
        running.set(true)
        readThread = thread(start = true, name = "Evo2UsbBoardRead") {
            while (running.get() && !Thread.currentThread().isInterrupted) {
                try {
                    val endpoint = boardReadEndpoint
                    val connection = boardConnection
                    if (endpoint == null || connection == null) {
                        Thread.sleep(100)
                        continue
                    }
                    val packetSize = endpoint.maxPacketSize.coerceAtLeast(64)
                    val buffer = ByteArray(packetSize)
                    val read = try {
                        connection.bulkTransfer(endpoint, buffer, buffer.size, READ_TIMEOUT_MS)
                    } catch (_: Throwable) {
                        -1
                    }
                    if (read > 0) {
                        handleBoardInput(buffer.copyOf(read))
                    }
                    Thread.sleep(100)
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                }
            }
        }
    }

    private fun handleBoardInput(data: ByteArray) {
        val report = normalizeBoardReport(data)
        if (report != null) {
            mainHandler.post { listener?.onFenPayload(report) }
            return
        }
        mainHandler.post { listener?.onResponse(data) }
    }

    private fun normalizeBoardReport(data: ByteArray): ByteArray? {
        if (data.size >= 35 &&
            data[0].toInt() == 0x00 &&
            data[1].toInt() == 0x01 &&
            data[2].toInt() == 0x24
        ) {
            return data.copyOfRange(1, data.size)
        }
        if (data.size >= 34 && data[0].toInt() == 0x01 && data[1].toInt() == 0x24) {
            return data
        }
        return null
    }

    private fun fillScreen(r: Int, g: Int, b: Int): Boolean {
        return writeLedPayload(
            byteArrayOf(
                CMD_FILL_SCREEN.toByte(),
                applyBrightness(r).toByte(),
                applyBrightness(g).toByte(),
                applyBrightness(b).toByte()
            )
        )
    }

    private fun fillRect(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        r: Int,
        g: Int,
        b: Int
    ): Boolean {
        return writeLedPayload(
            byteArrayOf(
                CMD_FILL_RECT.toByte(),
                x.toByte(),
                y.toByte(),
                width.toByte(),
                height.toByte(),
                applyBrightness(r).toByte(),
                applyBrightness(g).toByte(),
                applyBrightness(b).toByte()
            )
        )
    }

    private fun writePatternRegion(patternPixels: ByteArray, rotation: Int): Boolean {
        return writePatternRegion(
            patternPixels,
            LED_BOARD_REGION_X,
            LED_BOARD_REGION_Y,
            LED_BOARD_REGION_SIZE,
            LED_BOARD_REGION_SIZE,
            0,
            0,
            rotation
        )
    }

    private fun writePatternSquareRegion(
        patternPixels: ByteArray,
        square: Int,
        rotation: Int
    ): Boolean {
        val boardRow = square / 8
        val boardCol = square % 8
        return writePatternRegion(
            patternPixels,
            LED_ORIGIN_X + boardCol * LED_SQUARE_SIZE,
            LED_ORIGIN_Y + boardRow * LED_SQUARE_SIZE,
            LED_SQUARE_SIZE,
            LED_SQUARE_SIZE,
            boardCol * LED_SQUARE_SIZE,
            boardRow * LED_SQUARE_SIZE,
            rotation
        )
    }

    private fun writePatternRegion(
        patternPixels: ByteArray,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        patternRegionX: Int,
        patternRegionY: Int,
        rotation: Int
    ): Boolean {
        val seq = nextLedStreamSeq()
        if (!writeLedPayload(
                byteArrayOf(
                    CMD_REGION_BEGIN.toByte(),
                    (seq shr 8).toByte(),
                    seq.toByte(),
                    x.toByte(),
                    y.toByte(),
                    width.toByte(),
                    height.toByte()
                )
            )
        ) {
            return false
        }

        var offset = 0
        val totalPixels = width * height
        while (offset < totalPixels) {
            val count = minOf(LED_STREAM_MAX_PIXELS_PER_PACKET, totalPixels - offset)
            val packet = ByteArray(6 + count * 2)
            packet[0] = CMD_REGION_DATA.toByte()
            packet[1] = (seq shr 8).toByte()
            packet[2] = seq.toByte()
            packet[3] = (offset shr 8).toByte()
            packet[4] = offset.toByte()
            packet[5] = count.toByte()
            for (i in 0 until count) {
                val regionPixel = offset + i
                val patternX = patternRegionX + regionPixel % width
                val patternY = patternRegionY + regionPixel / width
                val boardCol = patternX / LED_SQUARE_SIZE
                val boardRow = patternY / LED_SQUARE_SIZE
                val cellCol = patternX % LED_SQUARE_SIZE
                val cellRow = patternY % LED_SQUARE_SIZE
                val cellIndex = rotatedPatternCellIndex(cellCol, cellRow, rotation)
                val patternOffset =
                    ((boardRow * 8 + boardCol) * LED_PATTERN_CELL_COUNT +
                        cellIndex) * 3
                val rgb565 = rgb565(
                    applyBrightness(patternPixels[patternOffset].toInt() and 0xff),
                    applyBrightness(patternPixels[patternOffset + 1].toInt() and 0xff),
                    applyBrightness(patternPixels[patternOffset + 2].toInt() and 0xff)
                )
                val dataOffset = 6 + i * 2
                packet[dataOffset] = (rgb565 shr 8).toByte()
                packet[dataOffset + 1] = rgb565.toByte()
            }
            if (!writeLedPayload(packet)) return false
            offset += count
        }

        return writeLedPayload(
            byteArrayOf(
                CMD_REGION_END.toByte(),
                (seq shr 8).toByte(),
                seq.toByte()
            )
        )
    }

    private fun rotatedPatternCellIndex(cellCol: Int, cellRow: Int, rotation: Int): Int {
        val max = LED_SQUARE_SIZE - 1
        val source = when (rotation) {
            Surface.ROTATION_90 -> Pair(cellRow, max - cellCol)
            Surface.ROTATION_180 -> Pair(max - cellCol, max - cellRow)
            Surface.ROTATION_270 -> Pair(max - cellRow, cellCol)
            else -> Pair(cellCol, cellRow)
        }
        return source.second * LED_SQUARE_SIZE + source.first
    }

    private fun applyBrightness(channel: Int): Int {
        return (channel.coerceIn(0, 255) * ledBrightness + 50) / 100
    }

    @Suppress("DEPRECATION")
    private fun currentDisplayRotation(): Int {
        displayRotationOverride?.let { return it }
        val windowManager =
            appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        return windowManager?.defaultDisplay?.rotation ?: Surface.ROTATION_0
    }

    private fun changedPatternSquares(previous: ByteArray?, next: ByteArray): List<Int> {
        val changed = mutableListOf<Int>()
        for (square in 0 until LED_BOARD_SQUARE_COUNT) {
            val squareOffset = square * LED_PATTERN_CELL_COUNT * 3
            var squareChanged = false
            for (cell in 0 until LED_PATTERN_CELL_COUNT) {
                val offset = squareOffset + cell * 3
                if (previous == null) {
                    val nextR = next[offset].toInt() and 0xff
                    val nextG = next[offset + 1].toInt() and 0xff
                    val nextB = next[offset + 2].toInt() and 0xff
                    if (nextR != 0 || nextG != 0 || nextB != 0) {
                        squareChanged = true
                        break
                    }
                    continue
                }
                if (previous[offset] != next[offset] ||
                    previous[offset + 1] != next[offset + 1] ||
                    previous[offset + 2] != next[offset + 2]
                ) {
                    squareChanged = true
                    break
                }
            }
            if (squareChanged) changed.add(square)
        }
        return changed
    }

    private fun nextLedStreamSeq(): Int {
        ledStreamSeq = (ledStreamSeq + 1) and 0xffff
        if (ledStreamSeq == 0) ledStreamSeq = 1
        return ledStreamSeq
    }

    private fun rgb565(r: Int, g: Int, b: Int): Int {
        return ((r and 0xf8) shl 8) or ((g and 0xfc) shl 3) or ((b and 0xf8) shr 3)
    }

    private fun writeLedPayload(payload: ByteArray): Boolean {
        val packet = ByteArray(64)
        payload.copyInto(packet, endIndex = payload.size.coerceAtMost(packet.size))
        synchronized(lock) {
            val connection = ledConnection ?: return false
            val endpoint = ledWriteEndpoint ?: return false
            val written = try {
                connection.bulkTransfer(endpoint, packet, packet.size, WRITE_TIMEOUT_MS)
            } catch (_: Throwable) {
                -1
            }
            return written == packet.size
        }
    }

    private fun closeBoard() {
        running.set(false)
        readThread?.interrupt()
        readThread = null
        synchronized(lock) {
            try {
                boardConnection?.releaseInterface(boardInterface)
            } catch (_: Throwable) {
            }
            try {
                boardConnection?.close()
            } catch (_: Throwable) {
            }
            boardDevice = null
            boardConnection = null
            boardInterface = null
            boardReadEndpoint = null
            boardWriteEndpoint = null
        }
    }

    private fun closeLed() {
        synchronized(lock) {
            try {
                ledConnection?.releaseInterface(ledInterface)
            } catch (_: Throwable) {
            }
            try {
                ledConnection?.close()
            } catch (_: Throwable) {
            }
            ledDevice = null
            ledConnection = null
            ledInterface = null
            ledWriteEndpoint = null
            ledRows = null
            ledPatternPixels = null
            ledPatternRotation = null
        }
    }

    private fun refreshConnectionState() {
        val connected = boardConnection != null || ledConnection != null
        setState(if (connected) ConnectionState.CONNECTED else ConnectionState.DISCONNECTED)
    }

    private fun findBoardDevice(): UsbDevice? {
        return usbManager.deviceList.values.firstOrNull(::isEvo2BoardDevice)
    }

    private fun findLedDevice(): UsbDevice? {
        return usbManager.deviceList.values.firstOrNull(::isEvo2LedDevice)
    }

    private fun findBoardInterface(device: UsbDevice): UsbInterface? {
        val preferred = (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull { it.id == BOARD_INTERFACE_NUMBER && it.endpointCount > 0 }
        if (preferred != null) return preferred
        return (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull { findEndpoint(it, UsbConstants.USB_DIR_IN) != null }
    }

    private fun findLedInterface(device: UsbDevice): UsbInterface? {
        return (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull { findEndpoint(it, UsbConstants.USB_DIR_OUT) != null }
    }

    private fun findEndpoint(
        usbInterface: UsbInterface,
        direction: Int
    ): UsbEndpoint? {
        return (0 until usbInterface.endpointCount)
            .map { usbInterface.getEndpoint(it) }
            .firstOrNull { it.direction == direction }
    }

    private fun requestPermission(device: UsbDevice) {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        val intent = Intent(ACTION_USB_PERMISSION).apply {
            setPackage(appContext.packageName)
        }
        val pendingIntent = PendingIntent.getBroadcast(appContext, 0, intent, flags)
        usbManager.requestPermission(device, pendingIntent)
    }

    private fun registerReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            appContext.registerReceiver(usbReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterReceiver() {
        if (!receiverRegistered) return
        try {
            appContext.unregisterReceiver(usbReceiver)
        } catch (_: Throwable) {
        }
        receiverRegistered = false
    }

    private fun setState(next: ConnectionState) {
        if (state == next) return
        state = next
        mainHandler.post { listener?.onConnectionStateChanged(next) }
    }

    private fun emitError(message: String) {
        mainHandler.post { listener?.onError(message) }
    }
}

private fun Intent.evo2UsbDeviceExtra(): UsbDevice? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
    } else {
        @Suppress("DEPRECATION")
        getParcelableExtra(UsbManager.EXTRA_DEVICE)
    }
}
