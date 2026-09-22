package com.chessnut.chessnutnext

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import android.widget.Toast

open class ChessnutHomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        ids.forEach { id ->
            manager.updateAppWidget(id, buildViews(context, isCompact = false))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE_VISION) {
            val requested = !HomeWidgetStore.readVisionEnabled(context)
            val next = requested && ChessnutAccessibilityService.isRunning
            if (requested && !next) {
                val message = VisionNotificationLanguage.localizedContext(context)
                    .getString(R.string.vision_accessibility_required)
                Toast.makeText(context, message, Toast.LENGTH_LONG).show()
            }
            HomeWidgetStore.writeVisionEnabled(context, next)
            HomeWidgetStore.writeLaunchAction(
                context,
                mapOf(
                    "action" to "toggleVision",
                    "visionEnabled" to next
                )
            )
            if (next) {
                val snapshot = HomeWidgetStore.readSnapshot(context)
                if (snapshot.boardState != "offline") {
                    BoardBackgroundConnectionService.start(context, snapshot.boardLabel)
                }
            }
            updateAll(context)
        }
    }

    fun buildViews(context: Context, isCompact: Boolean): RemoteViews {
        val snapshot = HomeWidgetStore.readSnapshot(context)
        val layout = if (isCompact) {
            R.layout.widget_quick_play
        } else {
            R.layout.widget_board_console
        }
        return RemoteViews(context.packageName, layout).apply {
            setTextViewText(
                R.id.widget_primary_action,
                if (isCompact) "Play" else "Play Now"
            )
            setTextViewText(R.id.widget_board_status, snapshot.boardLabel)
            setTextViewText(R.id.widget_vision_state, if (snapshot.visionEnabled) "On" else "Off")
            setTextColor(
                R.id.widget_vision_state,
                if (snapshot.visionEnabled) 0xFF86EFAC.toInt() else 0xFFCBD5E1.toInt()
            )
            setTextViewText(R.id.widget_battery, batteryBars(snapshot.batteryBars, snapshot.batteryLabel))
            setTextViewText(R.id.widget_recent_game, snapshot.recentLabel)
            setTextViewText(R.id.widget_last_game_chip, snapshot.recentLabel)
            setTextViewText(
                R.id.widget_date,
                java.text.SimpleDateFormat("MMM d  EEE", java.util.Locale.getDefault())
                    .format(java.util.Date())
            )
            setInt(
                R.id.widget_status_dot,
                "setColorFilter",
                when (snapshot.boardState) {
                    "lowBattery" -> 0xFFFFB020.toInt()
                    "offline" -> 0xFF94A3B8.toInt()
                    else -> 0xFF22C55E.toInt()
                }
            )

            if (!isCompact) {
                setOnClickPendingIntent(
                    R.id.widget_primary_action_shell,
                    launchPendingIntent(context, snapshot.primaryAction)
                )
            }
            setOnClickPendingIntent(
                R.id.widget_primary_action,
                launchPendingIntent(context, snapshot.primaryAction)
            )
            setOnClickPendingIntent(
                R.id.widget_board_status_row,
                launchPendingIntent(context, snapshot.boardAction)
            )
            setOnClickPendingIntent(
                R.id.widget_records_action,
                launchPendingIntent(context, "records")
            )
            setOnClickPendingIntent(
                R.id.widget_last_game_chip,
                launchPendingIntent(context, "continueGame")
            )
            setOnClickPendingIntent(
                R.id.widget_vision_toggle,
                broadcastPendingIntent(context, ACTION_TOGGLE_VISION)
            )
            setOnClickPendingIntent(
                R.id.widget_root,
                launchPendingIntent(context, "openApp")
            )
        }
    }

    companion object {
        const val ACTION_TOGGLE_VISION = "com.chessnut.chessnutnext.widget.TOGGLE_VISION"
        const val ACTION_WIDGET_LAUNCH = "com.chessnut.chessnutnext.widget.LAUNCH"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val console = ComponentName(context, ChessnutHomeWidgetProvider::class.java)
            val compact = ComponentName(context, ChessnutQuickPlayWidgetProvider::class.java)
            manager.updateAppWidget(
                console,
                ChessnutHomeWidgetProvider().buildViews(context, isCompact = false)
            )
            manager.updateAppWidget(
                compact,
                ChessnutQuickPlayWidgetProvider().buildViews(context, isCompact = true)
            )
        }

        fun pendingFlag(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        }

        fun launchPendingIntent(context: Context, action: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                this.action = ACTION_WIDGET_LAUNCH
                putExtra("widgetAction", action)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(
                context,
                requestCodeFor(action),
                intent,
                pendingFlag()
            )
        }

        fun broadcastPendingIntent(context: Context, action: String): PendingIntent {
            val intent = Intent(context, ChessnutHomeWidgetProvider::class.java).apply {
                this.action = action
            }
            return PendingIntent.getBroadcast(
                context,
                requestCodeFor(action),
                intent,
                pendingFlag()
            )
        }

        fun requestCodeFor(value: String): Int {
            return value.hashCode() and 0x7fffffff
        }

        fun batteryBars(bars: Int, label: String): String {
            if (bars <= 0) return label
            val filled = "|".repeat(bars.coerceIn(0, 5))
            val empty = "-".repeat((5 - bars).coerceIn(0, 5))
            return if (label.equals("Low battery", ignoreCase = true)) {
                "$filled$empty Low"
            } else {
                filled + empty
            }
        }
    }
}

class ChessnutQuickPlayWidgetProvider : ChessnutHomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        ids.forEach { id ->
            manager.updateAppWidget(id, buildViews(context, isCompact = true))
        }
    }
}

data class HomeWidgetSnapshot(
    val primaryLabel: String,
    val primaryAction: String,
    val boardLabel: String,
    val boardAction: String,
    val boardState: String,
    val batteryBars: Int,
    val batteryLabel: String,
    val recentLabel: String,
    val visionEnabled: Boolean
)

object HomeWidgetStore {
    private const val PREFS = "chessnut_home_widget"
    private const val KEY_PRIMARY_LABEL = "primaryLabel"
    private const val KEY_PRIMARY_ACTION = "primaryAction"
    private const val KEY_BOARD_LABEL = "boardLabel"
    private const val KEY_BOARD_ACTION = "boardAction"
    private const val KEY_BOARD_STATE = "boardState"
    private const val KEY_BATTERY_BARS = "batteryBars"
    private const val KEY_BATTERY_LABEL = "batteryLabel"
    private const val KEY_RECENT_LABEL = "recentLabel"
    private const val KEY_VISION_ENABLED = "visionEnabled"
    private const val KEY_PENDING_ACTION = "pendingAction"
    private const val KEY_PENDING_VISION = "pendingVisionEnabled"

    fun writeSnapshot(context: Context, values: Map<String, Any?>) {
        prefs(context).edit()
            .putString(KEY_PRIMARY_LABEL, values["primaryLabel"] as? String ?: "Play Now")
            .putString(KEY_PRIMARY_ACTION, values["primaryAction"] as? String ?: "playNow")
            .putString(KEY_BOARD_LABEL, values["boardLabel"] as? String ?: "Board offline")
            .putString(KEY_BOARD_ACTION, values["boardAction"] as? String ?: "connectBoard")
            .putString(KEY_BOARD_STATE, values["boardState"] as? String ?: "offline")
            .putInt(KEY_BATTERY_BARS, (values["batteryBars"] as? Number)?.toInt() ?: 0)
            .putString(KEY_BATTERY_LABEL, values["batteryLabel"] as? String ?: "No battery")
            .putString(KEY_RECENT_LABEL, values["recentLabel"] as? String ?: "No active game")
            .putBoolean(KEY_VISION_ENABLED,
                values["visionEnabled"] == true && ChessnutAccessibilityService.isRunning)
            .apply()
    }

    fun readSnapshot(context: Context): HomeWidgetSnapshot {
        val prefs = prefs(context)
        return HomeWidgetSnapshot(
            primaryLabel = prefs.getString(KEY_PRIMARY_LABEL, "Play Now") ?: "Play Now",
            primaryAction = prefs.getString(KEY_PRIMARY_ACTION, "playNow") ?: "playNow",
            boardLabel = prefs.getString(KEY_BOARD_LABEL, "Board offline") ?: "Board offline",
            boardAction = prefs.getString(KEY_BOARD_ACTION, "connectBoard") ?: "connectBoard",
            boardState = prefs.getString(KEY_BOARD_STATE, "offline") ?: "offline",
            batteryBars = prefs.getInt(KEY_BATTERY_BARS, 0),
            batteryLabel = prefs.getString(KEY_BATTERY_LABEL, "No battery") ?: "No battery",
            recentLabel = prefs.getString(KEY_RECENT_LABEL, "No active game") ?: "No active game",
            visionEnabled = readVisionEnabled(context)
        )
    }

    fun writeLaunchAction(context: Context, values: Map<String, Any?>) {
        val editor = prefs(context).edit()
            .putString(KEY_PENDING_ACTION, values["action"] as? String ?: "openApp")
        val vision = values["visionEnabled"]
        if (vision is Boolean) {
            editor.putBoolean(KEY_PENDING_VISION, vision)
        } else {
            editor.remove(KEY_PENDING_VISION)
        }
        editor.apply()
    }

    fun consumeLaunchAction(context: Context): Map<String, Any?>? {
        val prefs = prefs(context)
        val action = prefs.getString(KEY_PENDING_ACTION, null) ?: return null
        val hasVision = prefs.contains(KEY_PENDING_VISION)
        val result = mutableMapOf<String, Any?>("action" to action)
        if (hasVision) result["visionEnabled"] = prefs.getBoolean(KEY_PENDING_VISION, false)
        prefs.edit()
            .remove(KEY_PENDING_ACTION)
            .remove(KEY_PENDING_VISION)
            .apply()
        return result
    }

    fun readVisionEnabled(context: Context): Boolean {
        val saved = prefs(context).getBoolean(KEY_VISION_ENABLED, false)
        if (saved && !ChessnutAccessibilityService.isRunning) {
            writeVisionEnabled(context, false)
            return false
        }
        return saved
    }

    fun writeVisionEnabled(context: Context, enabled: Boolean) {
        val allowed = enabled && ChessnutAccessibilityService.isRunning
        val preferences = prefs(context)
        val editor = preferences.edit().putBoolean(KEY_VISION_ENABLED, allowed)
        if (!allowed && preferences.contains(KEY_PENDING_VISION)) {
            editor.putBoolean(KEY_PENDING_VISION, false)
        }
        editor.apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
