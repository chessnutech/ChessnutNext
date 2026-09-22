package com.chessnut.chessnutnext

import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.RemoteCallbackList
import android.os.SystemClock
import com.chessnut.chessnutnext.clock.IUsbClockListener
import com.chessnut.chessnutnext.clock.IUsbClockService
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class UsbClockService : Service() {
    companion object {
        // Chessnut 棋钟按钮设备
        private const val VENDOR_ID = 0x2d80
        private const val PRODUCT_ID = 0x0001 // 需要确认实际 PID

        private const val USB_TIMEOUT_MS = 2000
        private const val USB_READ_BUFFER_SIZE = 64
        private const val USB_WATCHDOG_INTERVAL_MS = 3000L
        private const val USB_READ_STALL_MS = 9000L

        private const val ACTION_USB_PERMISSION = "com.chessnut.chessnutnext.USB_PERMISSION"

        // 第三方 app 绑定时使用的 action
        const val ACTION_BIND_AIDL = "com.chessnut.chessnutnext.clock.UsbClockService"
    }

    private val binder = LocalBinder()
    private val isRunning = AtomicBoolean(false)
    private val isConnected = AtomicBoolean(false)

    // 跨进程事件监听器列表（供第三方 app 使用，自动处理 app 死亡清理）
    private val remoteCallbacks = RemoteCallbackList<IUsbClockListener>()

    // 主线程 Handler，用于在主线程发送事件
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var usbManager: UsbManager
    private var usbDevice: UsbDevice? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var endpointIn: UsbEndpoint? = null
    private var endpointOut: UsbEndpoint? = null

    private var readThread: Thread? = null
    private var listener: UsbClockListener? = null
    @Volatile
    private var lastReportedActiveSide: ClockSide? = null

    private var isReceiverRegistered = false

    // 自动重连相关
    private val reconnectHandler = Handler(Looper.getMainLooper())
    private var reconnectRunnable: Runnable? = null
    private val watchdogHandler = Handler(Looper.getMainLooper())
    private var watchdogRunnable: Runnable? = null
    @Volatile
    private var lastReadLoopAtMs = 0L
    private val reconnectDelayMs = 2000L // 2秒后尝试重连

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }

                        val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)

                        if (granted && device != null) {
                            connectToDevice(device)
                        } else {
                            notifyConnectionStateChanged(ConnectionState.DISCONNECTED)
                            mainHandler.post {
                                listener?.onError("USB permission denied")
                            }
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }

                    if (device?.vendorId == VENDOR_ID) {
                        connect()
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }

                    if (device?.deviceName == usbDevice?.deviceName) {
                        disconnect()
                    }
                }
            }
        }
    }

    inner class LocalBinder : Binder() {
        fun getService(): UsbClockService = this@UsbClockService
    }

    // 跨进程 AIDL binder，供第三方 app 绑定使用
    private val aidlBinder = object : IUsbClockService.Stub() {
        override fun registerListener(listener: IUsbClockListener?) {
            if (listener != null) {
                remoteCallbacks.register(listener)
                // 立即回报当前连接状态，方便新接入方同步
                try {
                    listener.onConnectionStateChanged(getConnectionState())
                } catch (e: Exception) {
                }
            }
        }

        override fun unregisterListener(listener: IUsbClockListener?) {
            if (listener != null) {
                remoteCallbacks.unregister(listener)
            }
        }

        override fun getConnectionState(): Int {
            return this@UsbClockService.getConnectionState().ordinal
        }

        override fun setActiveSide(side: Int): Boolean {
            val clockSide = when (side) {
                0 -> ClockSide.LEFT
                1 -> ClockSide.RIGHT
                else -> {
                    return false
                }
            }
            return this@UsbClockService.setActiveSide(clockSide)
        }

        override fun getActiveSide(): Int {
            return this@UsbClockService.getActiveSide()?.ordinal ?: -1
        }
    }

    override fun onBind(intent: Intent?): IBinder {
        // 第三方 app 通过 action 绑定，返回 AIDL binder；
        // 本进程（Flutter）通过 LocalBinder 绑定。
        return if (intent?.action == ACTION_BIND_AIDL) {
            aidlBinder
        } else {
            binder
        }
    }

    override fun onCreate() {
        super.onCreate()
        usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        registerUsbReceiver()
        startWatchdog()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopWatchdog()
        cancelReconnect()
        disconnect()
        unregisterUsbReceiver()
        remoteCallbacks.kill()
    }

    private fun registerUsbReceiver() {
        if (isReceiverRegistered) return

        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbReceiver, filter)
        }

        isReceiverRegistered = true
    }

    private fun unregisterUsbReceiver() {
        if (!isReceiverRegistered) return

        try {
            unregisterReceiver(usbReceiver)
            isReceiverRegistered = false
        } catch (e: Exception) {
        }
    }

    fun setListener(listener: UsbClockListener?) {
        this.listener = listener
    }

    /**
     * 连接到 USB HID 设备
     */
    fun connect(): Boolean {
        if (isConnected.get()) {
            return true
        }

        val device = findTargetDevice()
        if (device == null) {
            notifyConnectionStateChanged(ConnectionState.DISCONNECTED)
            return false
        }

        // 检查权限
        if (!usbManager.hasPermission(device)) {
            requestPermission(device)
            return false // 权限请求是异步的，会通过 receiver 回调
        }

        return connectToDevice(device)
    }

    /**
     * 请求 USB 权限
     */
    private fun requestPermission(device: UsbDevice) {
        val permissionIntent = PendingIntent.getBroadcast(
            this,
            0,
            Intent(ACTION_USB_PERMISSION).apply {
                setPackage(packageName)
            },
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        )
        usbManager.requestPermission(device, permissionIntent)
    }

    /**
     * 断开 USB 连接
     */
    fun disconnect() {
        disconnect(scheduleReconnect = false)
    }

    /**
     * 断开 USB 连接
     * @param scheduleReconnect 是否安排自动重连
     */
    private fun disconnect(scheduleReconnect: Boolean = false) {
        isRunning.set(false)
        readThread?.interrupt()
        readThread = null
        lastReadLoopAtMs = 0L

        usbConnection?.releaseInterface(usbInterface)
        usbConnection?.close()

        usbConnection = null
        usbInterface = null
        endpointIn = null
        endpointOut = null
        usbDevice = null
        lastReportedActiveSide = null

        isConnected.set(false)
        notifyConnectionStateChanged(ConnectionState.DISCONNECTED)


        // 如果需要自动重连
        if (scheduleReconnect) {
            scheduleReconnect()
        }
    }

    /**
     * 安排自动重连
     */
    private fun scheduleReconnect() {
        // 取消之前的重连任务
        cancelReconnect()


        reconnectRunnable = Runnable {
            reconnectRunnable = null
            val success = connect()
            if (success) {
                cancelReconnect()
            } else {
                // 重连失败，继续尝试
                scheduleReconnect()
            }
        }

        reconnectHandler.postDelayed(reconnectRunnable!!, reconnectDelayMs)
    }

    /**
     * 取消自动重连
     */
    private fun cancelReconnect() {
        reconnectRunnable?.let {
            reconnectHandler.removeCallbacks(it)
            reconnectRunnable = null
        }
    }

    private fun startWatchdog() {
        if (watchdogRunnable != null) return

        watchdogRunnable = object : Runnable {
            override fun run() {
                try {
                    runWatchdogCheck()
                } finally {
                    if (watchdogRunnable === this) {
                        watchdogHandler.postDelayed(this, USB_WATCHDOG_INTERVAL_MS)
                    }
                }
            }
        }
        watchdogHandler.postDelayed(watchdogRunnable!!, USB_WATCHDOG_INTERVAL_MS)
    }

    private fun stopWatchdog() {
        watchdogRunnable?.let {
            watchdogHandler.removeCallbacks(it)
            watchdogRunnable = null
        }
    }

    private fun runWatchdogCheck() {
        val device = findTargetDevice()

        if (!isConnected.get()) {
            if (device != null && reconnectRunnable == null) {
                scheduleReconnect()
            }
            return
        }

        if (device == null) {
            restartFromWatchdog()
            return
        }

        if (usbDevice?.deviceName != device.deviceName) {
            restartFromWatchdog()
            return
        }

        val thread = readThread
        if (!isRunning.get() || thread == null || !thread.isAlive) {
            restartFromWatchdog()
            return
        }

        if (usbConnection == null || usbInterface == null || endpointIn == null) {
            restartFromWatchdog()
            return
        }

        val lastProgress = lastReadLoopAtMs
        if (lastProgress > 0L &&
            SystemClock.elapsedRealtime() - lastProgress > USB_READ_STALL_MS
        ) {
            restartFromWatchdog()
        }
    }

    private fun restartFromWatchdog() {
        disconnect(scheduleReconnect = true)
    }

    /**
     * 查找目标 USB 设备
     */
    private fun findTargetDevice(): UsbDevice? {
        val deviceList = usbManager.deviceList ?: return null

        for ((_, device) in deviceList) {
            if (device.vendorId == VENDOR_ID) {
                return device
            }
        }

        return null
    }

    /**
     * 连接到指定设备
     */
    private fun connectToDevice(device: UsbDevice): Boolean {
        notifyConnectionStateChanged(ConnectionState.CONNECTING)

        // 检查权限
        if (usbManager?.hasPermission(device) != true) {
            notifyConnectionStateChanged(ConnectionState.DISCONNECTED)
            return false
        }

        // 查找 HID interface
        val hidInterface = findHidInterface(device)
        if (hidInterface == null) {
            notifyConnectionStateChanged(ConnectionState.DISCONNECTED)
            return false
        }

        // 打开连接
        val connection = usbManager?.openDevice(device)
        if (connection == null) {
            notifyConnectionStateChanged(ConnectionState.DISCONNECTED)
            return false
        }

        // Claim interface
        if (!connection.claimInterface(hidInterface, true)) {
            connection.close()
            notifyConnectionStateChanged(ConnectionState.DISCONNECTED)
            return false
        }

        // 查找 endpoints
        val (epIn, epOut) = findEndpoints(hidInterface)
        if (epIn == null) {
            connection.releaseInterface(hidInterface)
            connection.close()
            notifyConnectionStateChanged(ConnectionState.DISCONNECTED)
            return false
        }

        usbDevice = device
        usbConnection = connection
        usbInterface = hidInterface
        endpointIn = epIn
        endpointOut = epOut
        lastReportedActiveSide = null
        lastReadLoopAtMs = SystemClock.elapsedRealtime()

        isConnected.set(true)
        cancelReconnect()
        notifyConnectionStateChanged(ConnectionState.CONNECTED)

        // 启动读取线程
        startReadThread()

        return true
    }

    /**
     * 查找 HID interface (class 3, subclass 0, protocol 0)
     */
    private fun findHidInterface(device: UsbDevice): UsbInterface? {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == UsbConstants.USB_CLASS_HID) {
                return intf
            }
        }
        return null
    }

    /**
     * 查找 interrupt IN/OUT endpoints
     */
    private fun findEndpoints(intf: UsbInterface): Pair<UsbEndpoint?, UsbEndpoint?> {
        var epIn: UsbEndpoint? = null
        var epOut: UsbEndpoint? = null

        for (i in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT) {
                if (ep.direction == UsbConstants.USB_DIR_IN) {
                    epIn = ep
                } else if (ep.direction == UsbConstants.USB_DIR_OUT) {
                    epOut = ep
                }
            }
        }

        return Pair(epIn, epOut)
    }

    /**
     * 启动读取线程，轮询 interrupt IN endpoint
     */
    private fun startReadThread() {
        isRunning.set(true)
        readThread = thread(start = true, name = "UsbClockRead") {
            val buffer = ByteArray(USB_READ_BUFFER_SIZE)

            while (isRunning.get() && !Thread.currentThread().isInterrupted) {
                try {
                    val bytesRead = usbConnection?.bulkTransfer(
                        endpointIn,
                        buffer,
                        buffer.size,
                        USB_TIMEOUT_MS
                    ) ?: -1
                    lastReadLoopAtMs = SystemClock.elapsedRealtime()

                    if (bytesRead > 0) {
                        handleInputReport(buffer.copyOf(bytesRead))
                    } else if (bytesRead < 0 && bytesRead != -1) {
                        // 传输错误（-1 是超时，正常）
                        break
                    }
                    // bytesRead == -1 表示超时，继续循环
                } catch (e: Exception) {
                    if (isRunning.get()) {
                    }
                    break
                }
            }

            // 读取线程退出，触发断线重连
            if (isRunning.get()) {
                disconnect(scheduleReconnect = true)
            }
        }
    }

    /**
     * 处理从设备读取的 input report
     *
     * 协议格式（3字节）：
     * buffer[0]: 未知/保留
     * buffer[1]: 未知/保留
     * buffer[2]: 按钮状态
     *   - 0 = 左按钮按下
     *   - 1 = 右按钮按下
     */
    private fun handleInputReport(data: ByteArray) {
        if (data.size < 3) {
            return
        }

        val buttonState = data[2].toInt()
        val button = when (buttonState) {
            0 -> ClockSide.LEFT
            1 -> ClockSide.RIGHT
            else -> {
                return
            }
        }

        if (lastReportedActiveSide == button) {
            return
        }
        lastReportedActiveSide = button

        val event = ButtonEvent(button = button, pressed = true)

        // 在主线程调用 listener，因为 Flutter EventChannel 要求在主线程
        mainHandler.post {
            listener?.onButtonEvent(event)
        }

        // 广播给所有跨进程监听器（第三方 app）
        broadcastButtonEvent(event)

    }

    /**
     * 向所有跨进程监听器广播按钮事件
     */
    private fun broadcastButtonEvent(event: ButtonEvent) {
        val n = remoteCallbacks.beginBroadcast()
        try {
            for (i in 0 until n) {
                try {
                    remoteCallbacks.getBroadcastItem(i).onButtonEvent(
                        event.button.ordinal,
                        event.timestamp
                    )
                } catch (e: Exception) {
                }
            }
        } finally {
            remoteCallbacks.finishBroadcast()
        }
    }

    /**
     * 写 output report 到设备（通过 interrupt OUT endpoint）
     */
    private fun writeOutputReport(data: ByteArray): Boolean {
        if (!isConnected.get()) {
            return false
        }

        val endpoint = endpointOut
        if (endpoint != null) {
            val bytesWritten = usbConnection?.bulkTransfer(
                endpoint,
                data,
                data.size,
                USB_TIMEOUT_MS
            ) ?: -1

            if (bytesWritten != data.size) {
                restartFromWatchdog()
                return false
            }

            return true
        } else {
            // 无 OUT endpoint，使用 control transfer SET_REPORT
            return writeOutputReportViaControl(data)
        }
    }

    /**
     * 通过 control transfer 发送 SET_REPORT
     */
    private fun writeOutputReportViaControl(data: ByteArray): Boolean {
        val requestType = 0x21 // Host to Device, Class, Interface
        val request = 0x09      // SET_REPORT
        val value = 0x0200      // Output report, report ID 0
        val index = usbInterface?.id ?: 0

        val bytesWritten = usbConnection?.controlTransfer(
            requestType,
            request,
            value,
            index,
            data,
            data.size,
            USB_TIMEOUT_MS
        ) ?: -1

        if (bytesWritten != data.size) {
            restartFromWatchdog()
            return false
        }

        return true
    }

    /**
     * USB 热插拔监听
     */
    private fun notifyConnectionStateChanged(state: ConnectionState) {
        mainHandler.post {
            listener?.onConnectionStateChanged(state)
        }

        // 广播给所有跨进程监听器（第三方 app）
        val n = remoteCallbacks.beginBroadcast()
        try {
            for (i in 0 until n) {
                try {
                    remoteCallbacks.getBroadcastItem(i).onConnectionStateChanged(state.ordinal)
                } catch (e: Exception) {
                }
            }
        } finally {
            remoteCallbacks.finishBroadcast()
        }
    }

    // ==================== 业务方法（根据协议文档实现）====================

    /**
     * 切换激活侧（左/右）
     *
     * 协议格式（3字节）：
     * 左侧：[0x02, 0x01, 0x01]
     * 右侧：[0x01, 0x01, 0x02]
     */
    fun setActiveSide(side: ClockSide): Boolean {
        if (!isConnected.get()) {
            return false
        }

        val reportData = when (side) {
            ClockSide.LEFT -> byteArrayOf(0x02, 0x01, 0x01)
            ClockSide.RIGHT -> byteArrayOf(0x01, 0x01, 0x02)
        }

        return writeOutputReport(reportData)
    }

    fun getLastButton(): ClockSide? = lastReportedActiveSide

    fun getActiveSide(): ClockSide? = lastReportedActiveSide

    /**
     * 设置指示灯/LED
     * 注：参考代码未显示 LED 单独控制协议，此功能暂时使用 setActiveSide
     */
    fun setIndicator(leftOn: Boolean, rightOn: Boolean): Boolean {
        if (!isConnected.get()) {
            return false
        }

        // 根据参考代码，只能通过 setActiveSide 来切换指示灯
        // 如果需要更精细的控制，需要额外的协议文档
        return when {
            leftOn && !rightOn -> setActiveSide(ClockSide.LEFT)
            !leftOn && rightOn -> setActiveSide(ClockSide.RIGHT)
            else -> {
                false
            }
        }
    }

    /**
     * 读取当前按钮状态（被动接收模式）
     * HID 设备会主动上报按钮状态，无需主动查询
     */
    fun queryButtonState(): Boolean {
        // 根据协议，设备会主动上报，不支持主动查询
        return isConnected.get()
    }

    /**
     * 重置设备
     * 注：参考代码未显示重置协议
     */
    fun reset(): Boolean {
        return false
    }

    /**
     * 获取当前连接状态
     */
    fun getConnectionState(): ConnectionState {
        return if (isConnected.get()) {
            ConnectionState.CONNECTED
        } else {
            ConnectionState.DISCONNECTED
        }
    }

    // ==================== 数据类和接口 ====================

    enum class ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED
    }

    enum class ClockSide {
        LEFT,
        RIGHT
    }

    data class ButtonEvent(
        val button: ClockSide,
        val pressed: Boolean,
        val timestamp: Long = System.currentTimeMillis()
    )

    interface UsbClockListener {
        fun onConnectionStateChanged(state: ConnectionState)
        fun onButtonEvent(event: ButtonEvent)
        fun onError(error: String)
    }
}
