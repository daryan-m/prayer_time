package com.daryan.prayer

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import android.content.pm.ServiceInfo
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class AthanService : Service() {

    companion object {
        const val CHANNEL_ID   = "athan_foreground_channel"
        const val NOTIF_ID     = 9999
        const val EXTRA_SOUND  = "sound_file"
        const val EXTRA_PRAYER = "prayer_name"
        const val TAG          = "AthanService"
        const val ACTION_STOP  = "STOP_ATHAN"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private lateinit var audioManager: AudioManager

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // ── ئەگەر دوگمەی دابخە کلیک کرا ──
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val soundFile  = intent?.getStringExtra(EXTRA_SOUND)  ?: "kwait"
        val prayerName = intent?.getStringExtra(EXTRA_PRAYER) ?: "بانگ"

        // ── WakeLock: مۆبایل خەو نەبێت لە کاتی بانگ ──
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "AthanApp::AthanWakeLock"
        ).also { it.acquire(10 * 60 * 1000L) }

        // ── Foreground: ServiceCompat بۆ Android 14+ ──
        val notif = buildNotification(prayerName)
        ServiceCompat.startForeground(
            this,
            NOTIF_ID,
            notif,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        )

        // ── AudioFocus ──
        requestAudioFocus()

        // ── Volume: alarm channel بە max ──
        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)

        // ── پلەی دەنگ ──
        playSound(soundFile)

        return START_NOT_STICKY
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAcceptsDelayedFocusGain(false)
                .setWillPauseWhenDucked(false)
                .setOnAudioFocusChangeListener { }
                .build()
            audioFocusRequest = focusRequest
            audioManager.requestAudioFocus(focusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }

    private fun playSound(soundFile: String) {
        try {
            val cleanName = soundFile.replace(".mp3", "").lowercase().replace(" ", "_")
            val resId = resources.getIdentifier(cleanName, "raw", packageName)
            if (resId == 0) {
                Log.e(TAG, "Sound file not found in res/raw: '$cleanName'")
                stopSelf()
                return
            }

            Log.d(TAG, "Playing sound: $cleanName (resId=$resId)")

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                val afd = resources.openRawResourceFd(resId)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                prepare()
                start()
                setOnCompletionListener {
                    Log.d(TAG, "Playback complete — stopping service")
                    stopSelf()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what extra=$extra")
                    stopSelf()
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "playSound exception: ${e.message}")
            stopSelf()
        }
    }

    private fun buildNotification(prayerName: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── دوگمەی دابخە ──
        val stopIntent = Intent(this, AthanService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPi = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setContentTitle("کاتی بانگی $prayerName")
            .setContentText("ئێستا کاتی بانگە")
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_delete, "ڕاگرتنى دەنگ", stopPi)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "دەنگی بانگ",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "کەناڵی سێرڤیسی دەنگی بانگ"
                setSound(null, null)
                setBypassDnd(true)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "Service destroyed — releasing resources")
        try { mediaPlayer?.stop() } catch (_: Exception) {}
        mediaPlayer?.release()
        mediaPlayer = null
        wakeLock?.release()
        wakeLock = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}