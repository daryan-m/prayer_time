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

    /// millisecond ی کاتی بانگ دەگەڕێنێتەوە بۆ AlarmManager
    fun getPrayerTimeMillis(timeStr: String, isAfternoon: Boolean = false): Long {
        return try {
            val parts = timeStr.split(":")
            var hour = parts[0].toInt()
            val minute = parts[1].toInt()
            if (isAfternoon && hour < 12) hour += 12
            val cal = Calendar.getInstance()
            cal.set(Calendar.HOUR_OF_DAY, hour)
            cal.set(Calendar.MINUTE, minute)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.timeInMillis
        } catch (e: Exception) {
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
