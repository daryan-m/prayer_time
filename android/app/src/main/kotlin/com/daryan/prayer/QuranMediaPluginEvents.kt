package com.daryan.prayer

import io.flutter.plugin.common.EventChannel

/**
 * ڕووداوەکانی کۆتایی پلەیبەک (ئایەت) بۆ Flutter
 */
object QuranMediaPluginEvents {
    @JvmField
    var eventSink: EventChannel.EventSink? = null

    @JvmStatic
    fun emit(event: String) {
        val s = eventSink
        s?.success(event)
    }
}
