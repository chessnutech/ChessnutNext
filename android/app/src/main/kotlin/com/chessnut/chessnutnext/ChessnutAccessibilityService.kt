package com.chessnut.chessnutnext

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.res.Configuration
import android.view.accessibility.AccessibilityEvent

class ChessnutAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var instance: ChessnutAccessibilityService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        updateRunning(true)
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        updateRunning(true)
    }

    override fun onRebind(intent: Intent?) {
        super.onRebind(intent)
        updateRunning(true)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // The Flutter side asks for screenshots and gestures explicitly.
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        VisionStatusNotification.refresh(this)
    }

    override fun onInterrupt() {
        updateRunning(false)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        updateRunning(false)
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        updateRunning(false)
        super.onDestroy()
    }

    private fun updateRunning(running: Boolean) {
        isRunning = running
        instance = if (running) this else null
        if (!running) {
            HomeWidgetStore.writeVisionEnabled(this, false)
            VisionStatusNotification.clear(this)
            ChessnutHomeWidgetProvider.updateAll(this)
            return
        }
        VisionStatusNotification.refresh(this)
    }
}
