package com.daryan.prayer

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.Intent

class QuranMediaPlugin {
    companion object {
        const val METHOD_CHANNEL = "com.daryan.prayer/quran_media"
        const val EVENT_CHANNEL = "com.daryan.prayer/quran_media_events"
    }

    fun setupChannels(flutterEngine: FlutterEngine, context: android.content.Context) {
        // MethodChannel بۆ لیدان / وەستان / resume / stop
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        val isFile = call.argument<Boolean>("isFile") ?: true
                        val source = call.argument<String>("source") ?: return@setMethodCallHandler
                        val title = call.argument<String>("title") ?: "قورئان"
                        
                        val intent = Intent(context, QuranMediaService::class.java).apply {
                            action = QuranMediaService.ACTION_PLAY
                            putExtra(QuranMediaService.EXTRA_IS_FILE, isFile)
                            putExtra(QuranMediaService.EXTRA_SOURCE, source)
                            putExtra(QuranMediaService.EXTRA_TITLE, title)
                        }
                        context.startService(intent)
                        result.success(null)
                    }
                    "pause" -> {
                        val intent = Intent(context, QuranMediaService::class.java).apply {
                            action = QuranMediaService.ACTION_PAUSE
                        }
                        context.startService(intent)
                        result.success(null)
                    }
                    "resume" -> {
                        val intent = Intent(context, QuranMediaService::class.java).apply {
                            action = QuranMediaService.ACTION_RESUME
                        }
                        context.startService(intent)
                        result.success(null)
                    }
                    "stop" -> {
                        val intent = Intent(context, QuranMediaService::class.java).apply {
                            action = QuranMediaService.ACTION_STOP
                        }
                        context.startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // EventChannel بۆ ڕووداوەکان (complete, stopped, error)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    QuranMediaPluginEvents.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    QuranMediaPluginEvents.eventSink = null
                }
            })
    }
}