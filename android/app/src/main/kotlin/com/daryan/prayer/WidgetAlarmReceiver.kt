package com.daryan.prayer

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

class WidgetAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "WidgetAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Widget alarm received — updating widget")

        val appWidgetManager = AppWidgetManager.getInstance(context)
        val widgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, PrayerWidgetProvider::class.java)
        )
        for (id in widgetIds) {
            PrayerWidgetProvider.updateAppWidget(context, appWidgetManager, id)
        }
    }
}
