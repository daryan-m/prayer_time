package com.daryan.prayer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * AthanAlarmReceiver — AlarmManager کاتی بانگ بەرپا دەکات
 *
 * ئارکیتێکچەر:
 *   AlarmManager (exact) → AthanAlarmReceiver → AthanService.startForeground()
 *
 * AthanService:
 *   • MediaPlayer + STREAM_ALARM
 *   • WakeLock (ACQUIRE_CAUSES_WAKEUP)
 *   • AudioFocus AUDIOFOCUS_GAIN
 *   • بانگ لێ دەدات بەبێ پشتبەستن بە notification دەنگ
 */
class AthanAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "AthanAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Alarm received — starting AthanService")

        val soundFile  = intent.getStringExtra(AthanService.EXTRA_SOUND)  ?: "bang"
        val prayerName = intent.getStringExtra(AthanService.EXTRA_PRAYER) ?: "بانگ"

        val serviceIntent = Intent(context, AthanService::class.java).apply {
            putExtra(AthanService.EXTRA_SOUND,  soundFile)
            putExtra(AthanService.EXTRA_PRAYER, prayerName)
        }

        // ── Android 8+ پێویستی بە startForegroundService هەیە ──
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
