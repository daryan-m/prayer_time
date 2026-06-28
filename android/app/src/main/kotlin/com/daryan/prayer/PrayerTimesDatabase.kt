package com.daryan.prayer

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File
import java.util.Calendar

// ══════════════════════════════════════════════════════════════════════════════
// PrayerTimesDatabase
//
// کاتەکانی بانگ لە SQLite دەخوێنێتەوە کە Flutter پێشتر ذەخیرەی کردووە.
// بەبێ پێویستی بە Flutter کار دەکات.
//
// ── چاککراوەکان ──────────────────────────────────────────────────────────────
//  ١) getPrayerTimeMillis ئێستا (year, month, day)ـیش وەردەگرێت، بۆیە دەتوانرێت
//     کاتی بانگی بەیانیی ڕۆژی دواتر (دوای بانگی خەوتنان) بەدروستی بژێردرێت،
//     نەک هەمیشە بەروارى "ئەمڕۆ"ی سیستەم بەکاربێت.
//  ٢) "نیوەڕۆ" چیتر بەزۆرى نەکراوەتە "دوای نیوەڕۆ" (forcePm). ئێستا یاسای
//     ڕاستەقینە بەکاردێت: کاتژمێر ١٢ی دوای بانگی بەیانی (= نیوەڕۆی ڕاستەقینەی
//     ئەو ڕۆژە) دەکرێتە پیوەر؛ ئەگەر کاتژمێری خوێندراو لە ١٢ کەمتر بوو پێش
//     نیوەڕۆیە (بەبێ زیادکردن)، ئەگەرنا (١٢) دوای نیوەڕۆیە. پێشتر هەر کاتێک
//     کاتی ڕاستەقینەی "نیوەڕۆ" دەهاتە بۆ خوار کاتژمێر ١٢ (وەک ١١:٥٨)، کۆدی
//     کۆن دەیکردە ٢٣:٥٨ کە بەتەواوی هەڵە بوو.
// ══════════════════════════════════════════════════════════════════════════════

object PrayerTimesDatabase {

    private const val TAG = "PrayerTimesDatabase"
    private const val DB_NAME = "prayer_times.db"

    data class DayPrayers(
        val fajr: String,
        val sunrise: String,
        val dhuhr: String,
        val asr: String,
        val maghrib: String,
        val isha: String
    )

    /// کاتەکانی بانگی ڕۆژێکی دیاریکراو دەگەڕێنێتەوە
    fun getPrayerTimesForDay(context: Context, city: String, month: Int, day: Int): DayPrayers? {
        return try {
            val db = openDb(context) ?: return null
            val cursor = db.rawQuery(
                "SELECT fajr, sunrise, dhuhr, asr, maghrib, isha FROM prayer_times WHERE city=? AND month=? AND day=?",
                arrayOf(city, month.toString(), day.toString())
            )
            val result = if (cursor.moveToFirst()) {
                DayPrayers(
                    fajr    = cursor.getString(0),
                    sunrise = cursor.getString(1),
                    dhuhr   = cursor.getString(2),
                    asr     = cursor.getString(3),
                    maghrib = cursor.getString(4),
                    isha    = cursor.getString(5)
                )
            } else null
            cursor.close()
            db.close()
            result
        } catch (e: Exception) {
            Log.e(TAG, "getPrayerTimesForDay error: ${e.message}")
            null
        }
    }

    /// ئایا داتای ئەو شارە ذەخیرە کراوە
    fun isCitySaved(context: Context, city: String): Boolean {
        return try {
            val db = openDb(context) ?: return false
            val cursor = db.rawQuery(
                "SELECT 1 FROM prayer_times WHERE city=? LIMIT 1",
                arrayOf(city)
            )
            val exists = cursor.moveToFirst()
            cursor.close()
            db.close()
            exists
        } catch (e: Exception) {
            false
        }
    }

    /**
     * کاتژمێری 12-سەعەتی (بەبێ AM/PM لەناو داتاکەدا) دەگۆڕێت بۆ کاتژمێری 24-سەعەتی.
     *
     * یاسا: کاتژمێر ١٢ی دوای بانگی بەیانی (= نیوەڕۆی ڕاستەقینەی ئەو ڕۆژە) پیوەرە:
     *   • کاتژمێری خوێندراو < 12  → پێش ئەو ١٢ـیە دێت لەو ڕۆژەدا → پێش نیوەڕۆیە (AM)، بەبێ زیادکردن.
     *   • کاتژمێری خوێندراو == 12 → یا لەسەر نیوەڕۆیە یا تازە پەڕیوەتە دوای نیوەڕۆ
     *                              → لە سیستەمی 24-سعەتیدا خۆی وەک خۆی دەمێنێتەوە (هیچ زیادکردنێک نایەویت).
     *   • forcePm تەنها بۆ ئەو بانگانە بەکاردێت کە بەدڵنیاییەوە هەرگیز پێش
     *     نیوەڕۆ نایەن (عەسر، مەغریب، خەوتنان)؛ بۆ ئەوانە، ئەگەر کاتژمێری
     *     خوێندراو < 12 بوو، ١٢ زیاد دەکرێت چونکە بەدڵنیاییەوە دوای نیوەڕۆن.
     */
    private fun resolveHour24(rawHour: Int, forcePm: Boolean): Int {
        if (rawHour == 12) return 12
        return if (forcePm) rawHour + 12 else rawHour
    }

    /**
     * کاتی بانگێک دەگۆڕێت بۆ میلی چرکە (epoch millis) بۆ AlarmManager و بەراوردکردن.
     *
     * @param timeStr  کاتەکە بە شێوەی "HH:mm" (کاتژمێری 12-سەعەتی بەبێ AM/PM)
     * @param forcePm  true تەنها بۆ عەسر/مەغریب/خەوتنان. بۆ بەیانی، خۆرهەڵاتن،
     *                 و **نیوەڕۆ**، false بەکاربێنە (سەیری ڕاڤەی resolveHour24 بکە).
     * @param year/month/day  بەرواری ئەو ڕۆژەی کاتەکە بۆی حیساب دەکرێت. ئەگەر
     *                 نەدرێن، بەرواری ئەمڕۆ (سیستەم) بەکاردێت.
     */
    fun getPrayerTimeMillis(
        timeStr: String,
        forcePm: Boolean = false,
        year: Int = -1,
        month: Int = -1,
        day: Int = -1
    ): Long {
        return try {
            val parts = timeStr.split(":")
            val rawHour = parts[0].toInt()
            val minute = parts[1].toInt()
            val hour24 = resolveHour24(rawHour, forcePm)

            val cal = Calendar.getInstance()
            if (year > 0 && month in 1..12 && day in 1..31) {
                cal.set(year, month - 1, day, hour24, minute, 0)
            } else {
                cal.set(Calendar.HOUR_OF_DAY, hour24)
                cal.set(Calendar.MINUTE, minute)
                cal.set(Calendar.SECOND, 0)
            }
            cal.set(Calendar.MILLISECOND, 0)
            cal.timeInMillis
        } catch (e: Exception) {
            Log.e(TAG, "getPrayerTimeMillis error for '$timeStr': ${e.message}")
            -1L
        }
    }

    private fun openDb(context: Context): SQLiteDatabase? {
        return try {
            // Flutter sqflite داتابەیس لەم شوێنە ذەخیرە دەکات
            val dbPath = File(context.getDatabasePath(DB_NAME).absolutePath)
            if (!dbPath.exists()) {
                Log.w(TAG, "داتابەیس نەدۆزرایەوە: ${dbPath.absolutePath}")
                return null
            }
            SQLiteDatabase.openDatabase(
                dbPath.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY
            )
        } catch (e: Exception) {
            Log.e(TAG, "openDb error: ${e.message}")
            null
        }
    }
}