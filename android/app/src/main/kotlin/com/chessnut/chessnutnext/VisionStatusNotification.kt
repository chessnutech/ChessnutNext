package com.chessnut.chessnutnext

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/** Runtime state only: a saved toggle alone does not mean Vision is running. */
internal object VisionStatusNotification {
    private const val CHANNEL_ID = "chessnut_vision_status"
    private const val NOTIFICATION_ID = 3002

    var enabled = false
        private set
    private var recognizing = false
    private var boardConnected = false

    fun update(context: Context, enabled: Boolean, recognizing: Boolean, boardConnected: Boolean) {
        this.enabled = enabled && ChessnutAccessibilityService.isRunning
        this.recognizing = this.enabled && recognizing
        this.boardConnected = boardConnected
        refresh(context)
    }

    fun clear(context: Context) = update(context, false, false, false)

    fun refresh(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!enabled || !ChessnutAccessibilityService.isRunning) {
            enabled = false
            recognizing = false
            manager.cancel(NOTIFICATION_ID)
            return
        }
        val localizedContext = VisionNotificationLanguage.localizedContext(context)
        val channel = NotificationChannel(
            CHANNEL_ID,
            localizedContext.getString(R.string.vision_notification_channel),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return
        if (!manager.areNotificationsEnabled()) return

        val active = recognizing && boardConnected
        val message = localizedContext.getString(when {
            !boardConnected -> R.string.vision_notification_board
            active -> R.string.vision_notification_recognizing
            else -> R.string.vision_notification_ready
        })
        val openApp = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context, NOTIFICATION_ID, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_vision_notification)
            .setContentTitle(localizedContext.getString(if (active)
                R.string.vision_notification_active_title else R.string.vision_notification_title))
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setContentIntent(contentIntent)
            .setCategory(Notification.CATEGORY_STATUS)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Permission may be revoked between the check and notify().
        }
    }
}
