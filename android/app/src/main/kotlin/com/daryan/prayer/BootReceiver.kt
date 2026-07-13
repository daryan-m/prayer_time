package com.daryan.prayer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

// ── دوای ریستارتی مۆبایل، Flutter ئەپ دووبارە دەست پێ دەکات ──
// ئەپ خۆی ئەلارمەکانی دووبارە خشتە دەکات لە _loadSavedSettings

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            Log.d("BootReceiver", "Boot completed — launching app to reschedule athans")
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            if (launchIntent != null) {
                context.startActivity(launchIntent)
            }
        }
    }
}
