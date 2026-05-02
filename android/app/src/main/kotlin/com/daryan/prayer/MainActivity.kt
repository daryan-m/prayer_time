package com.daryan.prayer

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel.StreamHandler

class MainActivity : FlutterActivity() {

    companion object {
        const val ATHAN_CHANNEL = "com.daryan.prayer/athan"
        const val QURAN_MEDIA_CHANNEL = "com.daryan.prayer/quran_media"
        const val QURAN_MEDIA_EVENTS = "com.daryan.prayer/quran_media_events"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        QuranMediaPlugin().setupChannels(flutterEngine, this)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            QURAN_MEDIA_EVENTS
        ).setStreamHandler(object : StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                QuranMediaPluginEvents.eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                if (QuranMediaPluginEvents.eventSink != null) {
            QuranMediaPluginEvents.eventSink = null
        }
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            QURAN_MEDIA_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    try {
                        val isFile = call.argument<Boolean>("isFile")!!
                        val source = call.argument<String>("source")!!
                        val title = call.argument<String>("title")!!
                        val i = Intent(this, QuranMediaService::class.java).apply {
                            action = QuranMediaService.ACTION_PLAY
                            putExtra(QuranMediaService.EXTRA_IS_FILE, isFile)
                            putExtra(QuranMediaService.EXTRA_SOURCE, source)
                            putExtra(QuranMediaService.EXTRA_TITLE, title)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(i)
                        } else {
                            startService(i)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("QURAN_PLAY", e.message, null)
                    }
                }
                "pause" -> {
                    startService(
                        Intent(this, QuranMediaService::class.java)
                            .setAction(QuranMediaService.ACTION_PAUSE)
                    )
                    result.success(true)
                }
                "resume" -> {
                    startService(
                        Intent(this, QuranMediaService::class.java)
                            .setAction(QuranMediaService.ACTION_RESUME)
                    )
                    result.success(true)
                }
                "stop" -> {
                    startService(
                        Intent(this, QuranMediaService::class.java)
                            .setAction(QuranMediaService.ACTION_STOP)
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ATHAN_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // ── خشتەکردنی بانگ ──────────────────────────
                // Flutter scheduleAthan() بانگی دەکات
                // AlarmManager exact alarm دادەنرێت
                // کاتی بانگ: AthanAlarmReceiver → AthanService
                "scheduleAthan" -> {
                    try {
                        val id           = call.argument<Int>("id")!!
                        val prayerName   = call.argument<String>("prayerName")!!
                        val soundFile    = call.argument<String>("soundFile")!!
                        val scheduledMs  = call.argument<Long>("scheduledTime")!!

                        scheduleAthanAlarm(id, prayerName, soundFile, scheduledMs)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }

                // ── کەنسەڵکردنی بانگێک ──────────────────────
                "cancelAthan" -> {
                    try {
                        val id = call.argument<Int>("id")!!
                        cancelAthanAlarm(id)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }

                // ── کەنسەڵکردنی هەموو بانگەکان ─────────────
                "cancelAll" -> {
                    try {
                        cancelAllAthanAlarms()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ALL_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── AlarmManager: خشتەکردن ─────────────────────
    private fun scheduleAthanAlarm(
        id: Int,
        prayerName: String,
        soundFile: String,
        scheduledMs: Long
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(this, AthanAlarmReceiver::class.java).apply {
            putExtra(AthanService.EXTRA_SOUND,   soundFile)
            putExtra(AthanService.EXTRA_PRAYER,  prayerName)
            putExtra("alarm_id", id)
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)

        // ── Android 12+ پێویستی بە canScheduleExactAlarms هەیە ──
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    scheduledMs,
                    pendingIntent
                )
            } else {
                // fallback: inexact alarm
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    scheduledMs,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                scheduledMs,
                pendingIntent
            )
        }
    }

    // ── AlarmManager: کەنسەڵکردن ───────────────────
    private fun cancelAthanAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AthanAlarmReceiver::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()

        // ── AthanService وڕوو بگرە ئەگەر ئێستا دەنگ لێ دەدات ──
        stopService(Intent(this, AthanService::class.java))
    }

    // ── AlarmManager: هەموو کەنسەڵ ─────────────────
    // ID ی هەموو بانگەکان: hashCode ی ناوەکانیانە
    private fun cancelAllAthanAlarms() {
        val prayerNames = listOf("بەیانی", "نیوەڕۆ", "عەسر", "ئێوارە", "خەوتنان")
        val fixedIds    = listOf(1, 2, 3, 4, 5)

        val allIds = (prayerNames.map { it.hashCode() } + fixedIds).toSet()

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        for (id in allIds) {
            val intent = Intent(this, AthanAlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(this, id, intent, flags)
            alarmManager.cancel(pi)
            pi.cancel()
        }

        stopService(Intent(this, AthanService::class.java))
    }
}
