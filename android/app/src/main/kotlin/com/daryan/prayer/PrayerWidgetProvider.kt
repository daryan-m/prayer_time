package com.daryan.prayer

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.util.Log
import java.time.LocalDate
import java.time.chrono.HijrahDate
import java.util.Calendar

class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleAllPrayerAlarms(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelAllPrayerAlarms(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PRAYER_ALARM) {
            // کاتی بانگ هات — ویدجت ئەپدەیت بکە و ئەلارمی دواتر دابنێ
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, PrayerWidgetProvider::class.java)
            )
            for (id in ids) updateAppWidget(context, appWidgetManager, id)
            scheduleNextPrayerAlarm(context)
        } else if (intent.action == ACTION_MIDNIGHT_ALARM) {
            // ١٢ی شەو — ئەلارمەکانی سبەی دابنێ
            scheduleAllPrayerAlarms(context)
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, PrayerWidgetProvider::class.java)
            )
            for (id in ids) updateAppWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        const val TAG = "PrayerWidgetProvider"
        const val ACTION_PRAYER_ALARM = "com.daryan.prayer.PRAYER_ALARM"
        const val ACTION_MIDNIGHT_ALARM = "com.daryan.prayer.MIDNIGHT_ALARM"

        private val SLOT_IDS = intArrayOf(
            R.id.slot_fajr, R.id.slot_dhuhr, R.id.slot_asr,
            R.id.slot_maghrib, R.id.slot_isha
        )
        private val LBL_IDS = intArrayOf(
            R.id.lbl_fajr, R.id.lbl_dhuhr, R.id.lbl_asr,
            R.id.lbl_maghrib, R.id.lbl_isha
        )
        private val TIME_IDS = intArrayOf(
            R.id.time_fajr, R.id.time_dhuhr, R.id.time_asr,
            R.id.time_maghrib, R.id.time_isha
        )
        private val PRAYER_NAMES = arrayOf("بەیانی", "نیوەڕۆ", "عەسر", "ئێوارە", "خەوتنان")

        // ── چاککراوە: "نیوەڕۆ" چیتر بەزۆرى نەکراوەتە "دوای نیوەڕۆ" ─────────
        // (بەیانی، نیوەڕۆ، عەسر، مەغریب، خەوتنان) — تەنها عەسر/مەغریب/خەوتنان
        // بەدڵنیاییەوە "دوای نیوەڕۆ"ن. نیوەڕۆ بەپێی یاسای ١٢ی دوای بانگی
        // بەیانی خۆی دیاری دەکرێت (سەیری PrayerTimesDatabase.resolveHour24 بکە).
        private val FORCE_PM = booleanArrayOf(false, false, true, true, true)

        /// زانیاری بانگی داهاتوو — ئەگەر خەوتنانی ئەمڕۆ تێپەڕیوە، خۆکارانە
        /// دەگەڕێتەوە بۆ بانگی بەیانیی ڕۆژی دواتر (بە مانگ/ڕۆژی ڕاستەقینە)
        private data class NextPrayerInfo(
            val index: Int,
            val timeMillis: Long,
            val timeStr: String,
            val isTomorrow: Boolean
        )

        private fun findNextPrayer(
            context: Context, city: String, today: LocalDate, now: Long
        ): NextPrayerInfo? {
            val todayPrayers = PrayerTimesDatabase.getPrayerTimesForDay(
                context, city, today.monthValue, today.dayOfMonth
            ) ?: return null
            val rawTimes = arrayOf(
                todayPrayers.fajr, todayPrayers.dhuhr, todayPrayers.asr,
                todayPrayers.maghrib, todayPrayers.isha
            )

            for (i in 0..4) {
                val ms = PrayerTimesDatabase.getPrayerTimeMillis(
                    rawTimes[i], FORCE_PM[i], today.year, today.monthValue, today.dayOfMonth
                )
                if (now < ms) return NextPrayerInfo(i, ms, rawTimes[i], isTomorrow = false)
            }

            // ── خەوتنانی ئەمڕۆ تێپەڕیوە: بانگی بەیانیی سبەی دەبێتە "داهاتوو" ──
            val tomorrow = today.plusDays(1)
            val tomorrowPrayers = PrayerTimesDatabase.getPrayerTimesForDay(
                context, city, tomorrow.monthValue, tomorrow.dayOfMonth
            ) ?: return null
            val ms = PrayerTimesDatabase.getPrayerTimeMillis(
                tomorrowPrayers.fajr, forcePm = false,
                year = tomorrow.year, month = tomorrow.monthValue, day = tomorrow.dayOfMonth
            )
            return NextPrayerInfo(0, ms, tomorrowPrayers.fajr, isTomorrow = true)
        }

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val city = prefs.getString("flutter.selectedCity", "هەولێر") ?: "هەولێر"

            val today = LocalDate.now()
            val prayers = PrayerTimesDatabase.getPrayerTimesForDay(
                context, city, today.monthValue, today.dayOfMonth
            )

            val views = RemoteViews(context.packageName, R.layout.prayer_widget_layout)

            // ── بەروارەکان لە Kotlin حیساب دەکرێن ────────────────────────
            views.setTextViewText(R.id.txt_hijri, getHijriDate())
            views.setTextViewText(R.id.txt_gregorian, getGregorianDate(today))
            views.setTextViewText(R.id.txt_kurdish, getKurdishDate(today))

            if (prayers == null) {
                Log.w(TAG, "داتای بانگ نەدۆزرایەوە بۆ $city")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            // ── کاتەکانی بانگ ─────────────────────────────────────────────
            val rawTimes = arrayOf(
                prayers.fajr, prayers.dhuhr, prayers.asr,
                prayers.maghrib, prayers.isha
            )

            // ── بانگی داهاتوو دەستنیشان دەکات (لەگەڵ سەرژمێرکردنی دوای خەوتنان) ──
            val now = System.currentTimeMillis()
            val next = findNextPrayer(context, city, today, now)


         
if (next != null) {
    val nextPrayerName = if (next.isTomorrow || next.index == 0) "بەیانی" else PRAYER_NAMES[next.index]
    views.setTextViewText(R.id.txt_countdown_label, "ماوە بۆ بانگی $nextPrayerName")

    val remaining = next.timeMillis - now
    val base = android.os.SystemClock.elapsedRealtime() + remaining
    views.setChronometer(R.id.countdown_timer, base, null, true)
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
        views.setChronometerCountDown(R.id.countdown_timer, true)
    }
}




            for (i in 0..4) {
                views.setTextViewText(LBL_IDS[i], PRAYER_NAMES[i])

                // ئەگەر بانگی بەیانی پیشاندراوە بەهۆی تێپەڕینی خەوتنانی ئەمڕۆ،
                // کاتی بانگی بەیانیی سبەی پیشان بدە نەک کاتی ئەمڕۆی پێشووتر تێپەڕیو
                val showTomorrowFajr = (i == 0 && next?.isTomorrow == true)
                val timeForDisplay = if (showTomorrowFajr) next!!.timeStr else rawTimes[i]
                views.setTextViewText(TIME_IDS[i], formatTime(timeForDisplay, FORCE_PM[i]))

                if (next != null && i == next.index) {
                    views.setInt(SLOT_IDS[i], "setBackgroundResource", R.drawable.widget_slot_next_bg)
                    views.setTextColor(LBL_IDS[i], 0xFFFFFFFF.toInt())
                    views.setTextColor(TIME_IDS[i], 0xFFFFFFFF.toInt())
                } else {
                    views.setInt(SLOT_IDS[i], "setBackgroundResource", 0)
                    views.setTextColor(LBL_IDS[i], 0xFFFFFFFF.toInt())
                    views.setTextColor(TIME_IDS[i], 0xFFFFFFFF.toInt())
                }
            }

            // ── کلیکەکان ──────────────────────────────────────────────────
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
            views.setOnClickPendingIntent(R.id.btn_quran, pendingQuran)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // ── ئەلارمی هەموو بانگەکانی ئەمڕۆ دادەنرێت ──────────────────────
        fun scheduleAllPrayerAlarms(context: Context) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val city = prefs.getString("flutter.selectedCity", "هەولێر") ?: "هەولێر"
            val today = LocalDate.now()
            val prayers = PrayerTimesDatabase.getPrayerTimesForDay(
                context, city, today.monthValue, today.dayOfMonth
            ) ?: return

            val now = System.currentTimeMillis()
            val rawTimes = arrayOf(prayers.fajr, prayers.dhuhr, prayers.asr, prayers.maghrib, prayers.isha)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            for (i in 0..4) {
                val ms = PrayerTimesDatabase.getPrayerTimeMillis(
                    rawTimes[i], FORCE_PM[i], today.year, today.monthValue, today.dayOfMonth
                )
                if (ms <= now) continue // تێپەڕیوە

                val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
                    action = ACTION_PRAYER_ALARM
                }
                val pi = PendingIntent.getBroadcast(
                    context, 2000 + i, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setExactAlarm(alarmManager, ms, pi)
            }

            // ── ئەلارمی ١٢ی شەو بۆ سبەی ─────────────────────────────────
            scheduleMidnightAlarm(context)
        }

        private fun scheduleNextPrayerAlarm(context: Context) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val city = prefs.getString("flutter.selectedCity", "هەولێر") ?: "هەولێر"
            val today = LocalDate.now()
            val now = System.currentTimeMillis()

            // ── چاککراوە: ئەگەر هیچ بانگێکی ئەمڕۆ نەمابوو (دوای خەوتنان)،
            // ئەوا بانگی بەیانیی سبەی (بە مانگ/ڕۆژی ڕاستەقینە) دەبینرێتەوە ──
            val next = findNextPrayer(context, city, today, now) ?: return

            val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
                action = ACTION_PRAYER_ALARM
            }
            val pi = PendingIntent.getBroadcast(
                context, 2000 + next.index, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            setExactAlarm(alarmManager, next.timeMillis, pi)
        }

        private fun scheduleMidnightAlarm(context: Context) {
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 10)
                set(Calendar.MILLISECOND, 0)
            }
            val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
                action = ACTION_MIDNIGHT_ALARM
            }
            val pi = PendingIntent.getBroadcast(
                context, 1999, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            setExactAlarm(alarmManager, cal.timeInMillis, pi)
        }

        private fun cancelAllPrayerAlarms(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (i in 0..4) {
                val intent = Intent(context, PrayerWidgetProvider::class.java)
                val pi = PendingIntent.getBroadcast(
                    context, 2000 + i, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pi)
            }
            val midnightIntent = Intent(context, PrayerWidgetProvider::class.java)
            val midnightPi = PendingIntent.getBroadcast(
                context, 1999, midnightIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(midnightPi)
        }

        private fun setExactAlarm(alarmManager: AlarmManager, timeMs: Long, pi: PendingIntent) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pi)
            }
        }

        // ── بەروارەکان (دەستکاری نەکراون) ──────────────────────────────────

        private fun getGregorianDate(date: LocalDate): String {
            val day = toKurdishNums(date.dayOfMonth.toString().padStart(2, '0'))
            val month = toKurdishNums(date.monthValue.toString().padStart(2, '0'))
            val year = toKurdishNums(date.year.toString())
            return "$year/$month/$day"
        }

        private fun getHijriDate(): String {
            return try {
                val hijri = HijrahDate.now()
                val day = toKurdishNums(hijri.get(java.time.temporal.ChronoField.DAY_OF_MONTH).toString())
                val month = getHijriMonthName(hijri.get(java.time.temporal.ChronoField.MONTH_OF_YEAR))
                val year = toKurdishNums(hijri.get(java.time.temporal.ChronoField.YEAR).toString())
                " $dayى $month $year"
            } catch (e: Exception) {
                ""
            }
        }

        private fun getKurdishDate(date: LocalDate): String {
            val kurdishMonths = arrayOf(
                "نەورۆز", "گوڵان", "جۆزەردان", "پووشپەڕ", "گەلاوێژ", "خەرمانان",
                "ڕەزبەر", "گەڵاڕێزان", "سەرماوەز", "بەفرانبار", "ڕێبەندان", "ڕەشەمە"
            )
            val noroz = LocalDate.of(date.year, 3, 21)
            val kYear: Int
            val kMonth: Int
            val kDay: Int

            if (date.isBefore(noroz)) {
                kYear = date.year + 700 - 1
                val prevNoroz = LocalDate.of(date.year - 1, 3, 21)
                val diff = prevNoroz.until(date, java.time.temporal.ChronoUnit.DAYS).toInt()
                if (diff < 186) { kMonth = diff / 31 + 1; kDay = diff % 31 + 1 }
                else { val r = diff - 186; kMonth = r / 30 + 7; kDay = r % 30 + 1 }
            } else {
                kYear = date.year + 700
                val diff = noroz.until(date, java.time.temporal.ChronoUnit.DAYS).toInt()
                if (diff < 186) { kMonth = diff / 31 + 1; kDay = diff % 31 + 1 }
                else { val r = diff - 186; kMonth = r / 30 + 7; kDay = r % 30 + 1 }
            }

            val safeMonth = kMonth.coerceIn(1, 12)
            return "${toKurdishNums(kDay.toString())}ى ${kurdishMonths[safeMonth - 1]} ${toKurdishNums(kYear.toString())}"
        }

        private fun getHijriMonthName(month: Int): String {
            val months = arrayOf(
                "محەڕەم", "سەفەر", "ڕەبیعی یەکەم", "ڕەبیعی دووەم",
                "جومادی یەکەم", "جومادی دووەم", "ڕەجەب", "شەعبان",
                "ڕەمەزان", "شەوال", "ذوالقەعدە", "ذوالحیجە"
            )
            return months.getOrElse(month - 1) { "" }
        }

        // ── چاککراوە: چیتر بەزۆری "نیوەڕۆ" نەکراوەتە دوای نیوەڕۆ ───────────
        private fun formatTime(timeStr: String, forcePm: Boolean): String {
            return try {
                val parts = timeStr.split(":")
                val rawHour = parts[0].toInt()
                val m = parts[1].toInt()
                val hour24 = if (rawHour == 12) 12 else if (forcePm) rawHour + 12 else rawHour
                val h12 = if (hour24 % 12 == 0) 12 else hour24 % 12
                "${toKurdishNums(h12.toString().padStart(2, '0'))}:${toKurdishNums(m.toString().padStart(2, '0'))}"
            } catch (e: Exception) { timeStr }
        }

        private fun toKurdishNums(s: String): String {
            return s.replace('0', '٠').replace('1', '١').replace('2', '٢')
                .replace('3', '٣').replace('4', '٤').replace('5', '٥')
                .replace('6', '٦').replace('7', '٧').replace('8', '٨')
                .replace('9', '٩')
        }
    }
}