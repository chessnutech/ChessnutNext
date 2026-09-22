package com.chessnut.chessnut

import android.appwidget.AppWidgetManager
import android.content.Context
import com.chessnut.chessnutnext.ChessnutHomeWidgetProvider

class ChessnutHomeWidgetReceiver : ChessnutHomeWidgetProvider() {
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
