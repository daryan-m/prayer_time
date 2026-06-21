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
//     await prefs.setString('widget_next_name',    _getNextPrayerName(pt));
//     await prefs.setString('widget_next_time',    _nextTime(pt));
//     await prefs.setString('widget_remaining',    _getNextRemaining(pt));
//     await prefs.setString('widget_p0', '${prayerNames[0]} — ${_timeService.formatTo12Hr(todayTimes[0])}');
//     await prefs.setString('widget_p1', '${prayerNames[1]} — ${_timeService.formatTo12Hr(todayTimes[1])}');
//     await prefs.setString('widget_p2', '${prayerNames[2]} — ${_timeService.formatTo12Hr(todayTimes[2])}');
//     await prefs.setString('widget_p3', '${prayerNames[3]} — ${_timeService.formatTo12Hr(todayTimes[3])}');
//     await prefs.setString('widget_p4', '${prayerNames[4]} — ${_timeService.formatTo12Hr(todayTimes[4])}');
//     await prefs.setString('widget_p5', '${prayerNames[5]} — ${_timeService.formatTo12Hr(todayTimes[5])}');
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
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // ── داتاکانی بانگ لە Flutter وەردەگرێت ────────────────────────────
            val nextName   = prefs.getString("flutter.widget_next_name",  "نیوەڕۆ") ?: "نیوەڕۆ"
            val nextTime   = prefs.getString("flutter.widget_next_time",  "١٢:٣٠") ?: "١٢:٣٠"
            val remaining  = prefs.getString("flutter.widget_remaining",  "٢:٣٠:٠٠") ?: "--:--"
            val p0 = prefs.getString("flutter.widget_p0", "بەیانی — ٠٣:٤٢") ?: "بەیانی"
            val p1 = prefs.getString("flutter.widget_p1", "خۆرهەڵاتن — ٠٥:١٠") ?: "خۆرهەڵاتن"
            val p2 = prefs.getString("flutter.widget_p2", "نیوەڕۆ — ١٢:٣٠") ?: "نیوەڕۆ"
            val p3 = prefs.getString("flutter.widget_p3", "عەسر — ٠٤:٠٥") ?: "عەسر"
            val p4 = prefs.getString("flutter.widget_p4", "ئێوارە — ٠٧:٢٢") ?: "ئێوارە"
            val p5 = prefs.getString("flutter.widget_p5", "خەوتنان — ٠٩:١٠") ?: "خەوتنان"
            val hijri     = prefs.getString("flutter.widget_hijri",     "هـ — ١٥ ذو الحجة ١٤٤٦") ?: ""
            val gregorian = prefs.getString("flutter.widget_gregorian", "م — ١٣/٠٦/٢٠٢٥") ?: ""
            val kurdish   = prefs.getString("flutter.widget_kurdish",   "ک — ٢٣ گەلاوێژ") ?: ""

            // ── ڕووکارەکان دادەنێین ────────────────────────────────────────────
            val views = RemoteViews(context.packageName, R.layout.prayer_widget_layout)

            // قەوسی سەرەوە
            views.setTextViewText(R.id.txt_next_name, nextName)
            views.setTextViewText(R.id.txt_next_time, nextTime)
            views.setTextViewText(R.id.txt_remaining, "● $remaining ماوە")

            // کاتی بانگەکان
            views.setTextViewText(R.id.p0, p0)
            views.setTextViewText(R.id.p1, p1)
            views.setTextViewText(R.id.p2, p2)
            views.setTextViewText(R.id.p3, p3)
            views.setTextViewText(R.id.p4, p4)
            views.setTextViewText(R.id.p5, p5)

            // بەروارەکان
            views.setTextViewText(R.id.txt_hijri,     "هـ\n${hijri.replace("کۆچى: ", "")}")
            views.setTextViewText(R.id.txt_gregorian, "م\n${gregorian.replace("\u200E", "")}")
            views.setTextViewText(R.id.txt_kurdish,   "ک\n$kurdish")

            // ── کلیکەکان — کردنەوەی ئەپ ───────────────────────────────────────
            val openApp = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingOpen = PendingIntent.getActivity(
                context, 0, openApp,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // کردنەوەی قورئان
            val openQuran = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("open_screen", "quran")
            }
            val pendingQuran = PendingIntent.getActivity(
                context, 1, openQuran,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // کردنەوەی تەسبیح
            val openTasbih = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("open_screen", "tasbih")
            }
            val pendingTasbih = PendingIntent.getActivity(
                context, 2, openTasbih,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // کردنەوەی ناوەکانی خوا
            val openAllah = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("open_screen", "allah_names")
            }
            val pendingAllah = PendingIntent.getActivity(
                context, 3, openAllah,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.arch_section,  pendingOpen)
            views.setOnClickPendingIntent(R.id.btn_quran,     pendingQuran)
            views.setOnClickPendingIntent(R.id.btn_tasbih,    pendingTasbih)
            views.setOnClickPendingIntent(R.id.btn_allah,     pendingAllah)
            views.setOnClickPendingIntent(R.id.btn_settings,  pendingOpen)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
