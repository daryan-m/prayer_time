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
import android.view.WindowManager
import androidx.core.app.NotificationCompat

class AthanService : Service() {

    companion object {
        const val CHANNEL_ID     = "athan_foreground_channel"
        const val NOTIF_ID       = 9999
        const val EXTRA_SOUND    = "sound_file"
        const val EXTRA_PRAYER   = "prayer_name"
        const val TAG            = "AthanService"
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
        val soundFile  = intent?.getStringExtra(EXTRA_SOUND)  ?: "kamal_rauf"
        val prayerName = intent?.getStringExtra(EXTRA_PRAYER) ?: "بانگ"

        // ── WakeLock: مۆبایل خەو نەبێت + شاشە روناک بێت ──
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "AthanApp::AthanWakeLock"
        ).also { it.acquire(10 * 60 * 1000L) }

        // ── شاشە کردەوە + قفڵ لادەبرێت (وەک My Prayers) ──
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val activity = packageManager.getLaunchIntentForPackage(packageName)
            // بۆ service: window flag بەکاردەهێنین
        }

        // ── Foreground Notification ──
        val notif = buildNotification(prayerName)
        startForeground(NOTIF_ID, notif)

        // ── AudioFocus ──
        requestAudioFocus()

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
        }
    }

    private fun playSound(soundFile: String) {
        try {
            // ── پلەی دەنگی alarm بە زۆرترین ئاستی خۆی دابنێ ──
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)

            // ناوی فایل بەبێ .mp3 — res/raw/ دا هەیە
            val resId = resources.getIdentifier(soundFile, "raw", packageName)
            if (resId == 0) {
                Log.e(TAG, "Sound file not found: $soundFile")
                stopSelf()
                return
            }

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
                setOnCompletionListener { stopSelf() }
                setOnErrorListener { _, _, _ -> stopSelf(); false }
            }
        } catch (e: Exception) {
            Log.e(TAG, "MediaPlayer error: ${e.message}")
            stopSelf()
        }
    }

    private fun buildNotification(prayerName: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setContentTitle("کاتی بانگی $prayerName")
            .setContentText("ئێستا کاتی بانگەیە")
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
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
                setSound(null, null) // دەنگ لە MediaPlayer دێت نەک کەناڵەوە
                setBypassDnd(true)   // Do Not Disturb bypass
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        mediaPlayer?.stop()
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
