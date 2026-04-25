package com.daryan.prayer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import android.content.pm.ServiceInfo

class QuranMediaService : Service() {

    companion object {
        const val CHANNEL_ID = "quran_media_channel"
        const val NOTIF_ID = 8888
        const val ACTION_PLAY = "QURAN_PLAY"
        const val ACTION_PAUSE = "QURAN_PAUSE"
        const val ACTION_RESUME = "QURAN_RESUME"
        const val ACTION_STOP = "QURAN_STOP"
        const val EXTRA_IS_FILE = "is_file"
        const val EXTRA_SOURCE = "source"
        const val EXTRA_TITLE = "title"
        const val TAG = "QuranMediaService"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            return START_NOT_STICKY
        }
        when (intent.action) {
            ACTION_STOP -> {
                fullStop()
            }
            ACTION_PAUSE -> {
                try {
                    if (mediaPlayer?.isPlaying == true) {
                        mediaPlayer?.pause()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "pause: ${e.message}")
                }
            }
            ACTION_RESUME -> {
                try {
                    if (requestAudioFocus()) {
                        mediaPlayer?.start()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "resume: ${e.message}")
                }
            }
            ACTION_PLAY -> {
                val isFile = intent.getBooleanExtra(EXTRA_IS_FILE, true)
                val source = intent.getStringExtra(EXTRA_SOURCE) ?: return START_NOT_STICKY
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "قورئان"
                playNew(isFile, source, title)
            }
        }
        return START_NOT_STICKY
    }

    private fun playNew(isFile: Boolean, source: String, title: String) {
        releasePlayerOnly()
        if (!requestAudioFocus()) {
            Log.w(TAG, "audio focus not granted")
        }

        val notif = buildNotification(title)
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(
                this,
                NOTIF_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIF_ID, notif)
        }

        val mp = MediaPlayer()
        mediaPlayer = mp
        try {
            if (isFile) {
                mp.setDataSource(source)
            } else {
                mp.setDataSource(this, Uri.parse(source))
            }
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            mp.setAudioAttributes(attrs)
            mp.setOnPreparedListener { p ->
                try {
                    if (p === mediaPlayer) {
                        p.start()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "start: ${e.message}")
                }
            }
            mp.setOnCompletionListener {
                try {
                    QuranMediaPluginEvents.emit("complete")
                } catch (e: Exception) {
                    Log.e(TAG, "emit: ${e.message}")
                }
            }
            mp.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "onError $what $extra")
                try {
                    QuranMediaPluginEvents.emit("error")
                } catch (_: Exception) { }
                fullStop()
                true
            }
            mp.prepareAsync()
        } catch (e: Exception) {
            Log.e(TAG, "playNew: ${e.message}")
            try {
                QuranMediaPluginEvents.emit("error")
            } catch (_: Exception) { }
            fullStop()
        }
    }

    private fun requestAudioFocus(): Boolean {
        val am = audioManager ?: return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener { }
                .build()
            audioFocusRequest = req
            return am.requestAudioFocus(req) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
        @Suppress("DEPRECATION")
        return am.requestAudioFocus(
            null,
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN
        ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun buildNotification(title: String): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stop = Intent(this, QuranMediaService::class.java).apply { action = ACTION_STOP }
        val stopPi = PendingIntent.getService(
            this, 1, stop,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText("لێدەری قورئان")
            .setContentIntent(pi)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(0, "ڕاگرتن", stopPi)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "لێدەری قورئان",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "دەنگی تێکستی قورئان"
                setSound(null, null)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun releasePlayerOnly() {
        try {
            mediaPlayer?.setOnCompletionListener(null)
            mediaPlayer?.setOnErrorListener(null)
            mediaPlayer?.setOnPreparedListener(null)
            mediaPlayer?.stop()
        } catch (_: Exception) { }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) { }
        mediaPlayer = null
    }

    private fun fullStop() {
        try {
            QuranMediaPluginEvents.emit("stopped")
        } catch (_: Exception) { }
        releasePlayerOnly()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } catch (_: Exception) { }
        }
        audioFocusRequest = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } catch (_: Exception) { }
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        try {
            stopSelf()
        } catch (_: Exception) { }
    }

    override fun onDestroy() {
        releasePlayerOnly()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } catch (_: Exception) { }
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
