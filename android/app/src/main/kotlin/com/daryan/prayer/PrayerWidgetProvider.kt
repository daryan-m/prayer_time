package com.daryan.prayer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale


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

        /**
         * کاتژمێری ١٢-کاتژمێری لەگەڵ AM/PM (وەک "03:42 AM") دەگۆڕێت بۆ
         * ژمارەی خولەک لە نیوەشەوەوە (٠ - ١٤٣٩). ئەگەر parse سەرکەوتوو
         * نەبوو، -1 دەگەڕێنێتەوە (بۆ پاراستن لە crash).
         */
        private fun parseToMinutes(timeStr: String): Int {
            return try {
                val cleaned = timeStr.trim().uppercase(Locale.ROOT)
                val isPM = cleaned.contains("PM")
                val isAM = cleaned.contains("AM")
                val numericPart = cleaned.replace("AM", "").replace("PM", "").trim()
                val parts = numericPart.split(":")
                var hour = parts[0].trim().toInt()
                val minute = parts[1].trim().toInt()

                if (isPM && hour != 12) hour += 12
                if (isAM && hour == 12) hour = 0

                hour * 60 + minute
            } catch (e: Exception) {
                -1
            }
        }

        /**
         * کاتی ئێستای سیستەم (لای ئامێر) دەگەڕێنێتەوە بە خولەک لە
         * نیوەشەوەوە.
         */
        private fun currentMinutesOfDay(): Int {
            val cal = Calendar.getInstance()
            return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        }

        /**
         * بەپێی کاتی ئێستا، ئینێکسی یەکەم بانگی داهاتوو دەدۆزێتەوە.
         * [times] دەبێت بەڕیزی فجر→عشاء بێت (0=فجر, 1=دهر, 2=عصر, 3=مغرب, 4=عشاء).
         * ئەگەر هەموو کاتەکان تێپەربوون (دوای عشاء)، 0 (فجری بەیانی) دەگەڕێنێتەوە.
         */
        private fun calculateNextIndex(times: Array<String>): Int {
            val nowMinutes = currentMinutesOfDay()
            for (i in times.indices) {
                val prayerMinutes = parseToMinutes(times[i])
                if (prayerMinutes != -1 && nowMinutes < prayerMinutes) {
                    return i
                }
            }
            return 0
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // ── کاتژمێرە خاوەکراوەکان (لەگەڵ AM/PM) — بەڕیزی RTL‌ـی پیشاندان ──
            // Flutter p0=بەیانی...p4=خەوتنان — ئێمە عەکس دەخوێنینەوە بۆ ڕاستەوە-چەپ
            val rawTimes = Array(5) { i ->
                val flutterIndex = 4 - i
                prefs.getString("flutter.widget_p${flutterIndex}_time", defaultTimes[i]) ?: defaultTimes[i]
            }

            // ── ناوی پێنج بانگ — عەکسەوە بۆ RTL ────────────────────────────────
            val names = Array(5) { i ->
                val flutterIndex = 4 - i
                prefs.getString("flutter.widget_p${flutterIndex}_name", defaultNames[i]) ?: defaultNames[i]
            }

            // ── کاتژمێرە پاککراوەکان (بەبێ AM/PM) — بۆ پیشاندان ────────────────
            val times = rawTimes.map { raw ->
                raw.replace(Regex("(?i)\\s*(AM|PM|د\\.ن|پ\\.ن)\\s*"), "").trim()
            }.toTypedArray()

            // ── حسابکردنی nextIndex بەخۆی Kotlin، بەپێی کاتی ڕاستەقینەی سیستەم ──
            // rawTimes بەڕیزی RTL‌ـن (i=0 → خەوتنان لای flutterIndex=4)، کەواتە
            // پێویستە بگوازرێنەوە بۆ ڕیزی Flutter‌ـی ڕاستەقینە (0=فجر...4=عشاء)
            // پێش ناردن بۆ calculateNextIndex.
            val flutterOrderedTimes = Array(5) { i -> rawTimes[4 - i] }
            val flutterNextIndex = calculateNextIndex(flutterOrderedTimes)
            val nextIndex = 4 - flutterNextIndex

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

                if (i == nextIndex) {
                    // بانگی داهاتوو — هایلایتی سەوز
                    views.setInt(SLOT_IDS[i], "setBackgroundResource", R.drawable.widget_slot_next_bg)
                    views.setTextColor(LBL_IDS[i],  0xFFFFFFFF.toInt())
                    views.setTextColor(TIME_IDS[i], 0xFF66BB6A.toInt())
                } else {
                    // بانگی تێپەڕیوو و دواتر — هەردووکیان بەهەمان شێوازی ئاسایی
                    views.setInt(SLOT_IDS[i], "setBackgroundResource", 0)
                    views.setTextColor(LBL_IDS[i],  0xCCFFFFFF.toInt())
                    views.setTextColor(TIME_IDS[i], 0xFFFFFFFF.toInt())
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

        private val defaultNames = arrayOf("خەوتنان", "ئێوارە", "عەسر", "نیوەڕۆ", "بەیانی")
        private val defaultTimes = arrayOf("09:10 PM", "07:22 PM", "04:05 PM", "12:30 PM", "03:42 AM")
    }
}