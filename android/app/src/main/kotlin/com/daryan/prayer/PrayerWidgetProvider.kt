package com.daryan.prayer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

// ══════════════════════════════════════════════════════════════════════════════
// PrayerWidgetProvider
//
// داتا لە SharedPreferences وەردەگرێت کە Flutter پێشتر ذەخیرەی کردووە.
//
// لە Flutter (home_screen.dart) ئەمانە زیاد بکە بۆ نوێکردنەوەی ویدجت:
//
//   import 'package:shared_preferences/shared_preferences.dart';
//   import 'package:home_widget/home_widget.dart';
//
//   Future<void> _updateWidget(PrayerTimes pt) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('widget_next_index',  _getNextPrayerIndex(pt).toString());
//     await prefs.setString('widget_p0_name', prayerNames[0]);
//     await prefs.setString('widget_p0_time', _timeService.formatTo12Hr(todayTimes[0]));
//     await prefs.setString('widget_p1_name', prayerNames[1]);
//     await prefs.setString('widget_p1_time', _timeService.formatTo12Hr(todayTimes[1]));
//     await prefs.setString('widget_p2_name', prayerNames[2]);
//     await prefs.setString('widget_p2_time', _timeService.formatTo12Hr(todayTimes[2]));
//     await prefs.setString('widget_p3_name', prayerNames[3]);
//     await prefs.setString('widget_p3_time', _timeService.formatTo12Hr(todayTimes[3]));
//     await prefs.setString('widget_p4_name', prayerNames[4]);
//     await prefs.setString('widget_p4_time', _timeService.formatTo12Hr(todayTimes[4]));
//     await prefs.setString('widget_p5_name', prayerNames[5]);
//     await prefs.setString('widget_p5_time', _timeService.formatTo12Hr(todayTimes[5]));
//     await prefs.setString('widget_hijri',     _timeService.hijriDateString());
//     await prefs.setString('widget_gregorian', _timeService.gregorianDateString(_now));
//     await prefs.setString('widget_kurdish',   _timeService.kurdishDateString(_now));
//     await HomeWidget.updateWidget(androidName: 'PrayerWidgetProvider');
//   }
//
//   // _updateWidget بانگ بکە لەدوای بارکردنی داتا:
//   // لە _initAppData() دوای _loadSavedSettings()
//   // لە _ticker (هەر ٣٠ چرکە یەک جار)
// ══════════════════════════════════════════════════════════════════════════════

class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {

        // slot IDs بەئاستی index — بۆ هایلایت کردن
        private val SLOT_IDS = intArrayOf(
            R.id.slot_fajr,
            R.id.slot_dhuhr,
            R.id.slot_asr,
            R.id.slot_maghrib,
            R.id.slot_isha
        )

        private val LBL_IDS = intArrayOf(
            R.id.lbl_fajr,
            R.id.lbl_dhuhr,
            R.id.lbl_asr,
            R.id.lbl_maghrib,
            R.id.lbl_isha
        )

        private val TIME_IDS = intArrayOf(
            R.id.time_fajr,
            R.id.time_dhuhr,
            R.id.time_asr,
            R.id.time_maghrib,
            R.id.time_isha
        )

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // ── ئینێکسی بانگی داهاتوو — عەکسەوە بۆ RTL ─────────────────────────
            val flutterNext = prefs.getString("flutter.widget_next_index", "0")?.toIntOrNull() ?: 0
            val nextIndex = 4 - flutterNext

            // ── ناو و کاتی پێنج بانگ — عەکسەوە بۆ RTL ─────────────────────────
            // Flutter p0=بەیانی...p4=خەوتنان — ئێمە عەکس دەخوێنینەوە بۆ ڕاستەوە-چەپ
            val names = Array(5) { i ->
                val flutterIndex = 4 - i
                prefs.getString("flutter.widget_p${flutterIndex}_name", defaultNames[i]) ?: defaultNames[i]
            }
            val times = Array(5) { i ->
                val flutterIndex = 4 - i
                val raw = prefs.getString("flutter.widget_p${flutterIndex}_time", defaultTimes[i]) ?: defaultTimes[i]
                raw.replace(Regex("(?i)\\s*(AM|PM|د\\.ن|پ\\.ن)\\s*"), "").trim()
            }

            // ── بەروارەکان ───────────────────────────────────────────────────
            val hijri     = prefs.getString("flutter.widget_hijri",     " ١٥ ذو الحجة ١٤٤٦") ?: ""
            val gregorian = prefs.getString("flutter.widget_gregorian", " ٢٠٢٥/٠٦/١٣") ?: ""
            val kurdish   = prefs.getString("flutter.widget_kurdish",   " ٢٣ گەلاوێژ") ?: ""

            // ── ڕووکارەکان دادەنێین ───────────────────────────────────────────
            val views = RemoteViews(context.packageName, R.layout.prayer_widget_layout)

            // بەروارەکان — تەک خەت بەبێ نیوێ
            views.setTextViewText(R.id.txt_hijri,     hijri.replace("کۆچى: ", ""))
            views.setTextViewText(R.id.txt_gregorian, gregorian.replace("\u200E", ""))
            views.setTextViewText(R.id.txt_kurdish,   kurdish)

            // کاتەکانی بانگ + هایلایت
            for (i in 0..4) {
                views.setTextViewText(LBL_IDS[i],  names[i])
                views.setTextViewText(TIME_IDS[i], times[i])

                when {
                    i == nextIndex -> {
                        // بانگی داهاتوو — هایلایتی سەوز
                        views.setInt(SLOT_IDS[i], "setBackgroundResource", R.drawable.widget_slot_next_bg)
                        views.setTextColor(LBL_IDS[i],  0xFFFFFFFF.toInt())
                        views.setTextColor(TIME_IDS[i], 0xFF66BB6A.toInt())
                    }
                    
                    else -> {
                        // بانگی دواتر — ئاسایی
                        views.setInt(SLOT_IDS[i], "setBackgroundResource", 0)
                        views.setTextColor(LBL_IDS[i],  0xFFFFFFFF.toInt())
                        views.setTextColor(TIME_IDS[i], 0xFFFFFFFF.toInt())
                    }
                }
            }

            // ── کلیکەکان ─────────────────────────────────────────────────────
            val openApp = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingOpen = PendingIntent.getActivity(
                context, 0, openApp,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val openQuran = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("open_screen", "quran")
            }
            val pendingQuran = PendingIntent.getActivity(
                context, 1, openQuran,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.arch_section, pendingOpen)
            views.setOnClickPendingIntent(R.id.btn_quran,    pendingQuran)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun triggerUpdate(context: Context) {
    val appWidgetManager = AppWidgetManager.getInstance(context)
    val widgetIds = appWidgetManager.getAppWidgetIds(
        android.content.ComponentName(context, PrayerWidgetProvider::class.java)
    )
    for (id in widgetIds) {
        updateAppWidget(context, appWidgetManager, id)
    }
}

        private val defaultNames = arrayOf("خەوتنان", "ئێوارە", "عەسر", "نیوەڕۆ", "بەیانی")
        private val defaultTimes = arrayOf("٠٩:١٠", "٠٧:٢٢", "٠٤:٠٥", "١٢:٣٠", "٠٣:٤٢")
    }
}