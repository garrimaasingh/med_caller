package com.example.med_caller

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts the foreground service after device reboot.
 * Requires: <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" // HTC / Samsung
        ) {
            MedCallerForegroundService.start(context)
        }
    }
}
