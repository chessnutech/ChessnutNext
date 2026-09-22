package com.chessnut.chessnutnext

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import android.util.Log
import java.io.File

class Evo2UsbPowerController(
    context: Context,
    private val onScreenStateChanged: (Boolean) -> Unit
) {
    private val appContext = context.applicationContext
    private val powerManager =
        appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val keyguardManager =
        appContext.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
    private var keepBoardConnectedEnabled = false
    private var gameActive = false
    private var usbPowerEnabled: Boolean? = readUsbPowerState()
    private var receiverRegistered = false
    private var wakeLock: PowerManager.WakeLock? = null

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    onScreenStateChanged(true)
                    applyScreenOffPolicy()
                }
                Intent.ACTION_USER_PRESENT -> restoreAfterUnlock()
                Intent.ACTION_SCREEN_ON -> {
                    if (!keyguardManager.isKeyguardLocked) {
                        restoreAfterUnlock()
                    }
                }
            }
        }
    }

    fun start() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(
                screenReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            appContext.registerReceiver(screenReceiver, filter)
        }
        receiverRegistered = true
    }

    fun dispose() {
        releaseWakeLock()
        if (!receiverRegistered) return
        try {
            appContext.unregisterReceiver(screenReceiver)
        } catch (_: Throwable) {
        }
        receiverRegistered = false
    }

    fun isScreenOff(): Boolean {
        return !powerManager.isInteractive || keyguardManager.isKeyguardLocked
    }

    fun setScreenOffPolicy(enabled: Boolean, active: Boolean): Boolean {
        keepBoardConnectedEnabled = enabled
        gameActive = active
        return if (isScreenOff()) applyScreenOffPolicy() else true
    }

    fun setUsbPower(enabled: Boolean): Boolean {
        releaseWakeLock()
        return writeUsbPower(enabled)
    }

    fun onActivityResumed() {
        if (!isScreenOff()) {
            restoreAfterUnlock()
        }
    }

    private fun applyScreenOffPolicy(): Boolean {
        return if (keepBoardConnectedEnabled && gameActive) {
            acquireWakeLock()
            val powered = writeUsbPower(true)
            if (!powered) releaseWakeLock()
            powered
        } else {
            releaseWakeLock()
            // Keep the board connected; Dart suppresses moves and LEDs while
            // screen-off play is disabled.
            writeUsbPower(true)
        }
    }

    private fun restoreAfterUnlock() {
        writeUsbPower(true)
        releaseWakeLock()
        onScreenStateChanged(false)
    }

    private fun acquireWakeLock() {
        val existing = wakeLock
        if (existing?.isHeld == true) return
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Chessnut:Evo2ScreenOffGame"
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWakeLock() {
        val lock = wakeLock
        if (lock?.isHeld == true) {
            try {
                lock.release()
            } catch (_: Throwable) {
            }
        }
        wakeLock = null
    }

    private fun writeUsbPower(enabled: Boolean): Boolean {
        if (usbPowerEnabled == enabled) return true
        return try {
            USB_POWER_FILE.writeText(if (enabled) "1" else "0")
            usbPowerEnabled = enabled
            true
        } catch (error: Throwable) {
            Log.w(TAG, "Unable to set EVO2 USB power to $enabled", error)
            false
        }
    }

    private fun readUsbPowerState(): Boolean? {
        return try {
            when (USB_POWER_FILE.readText().trim()) {
                "1" -> true
                "0" -> false
                else -> null
            }
        } catch (_: Throwable) {
            null
        }
    }

    companion object {
        private val USB_POWER_FILE = File("/sys/class/bnd_gpio_en/enable")
        private const val TAG = "Evo2UsbPower"
    }
}
