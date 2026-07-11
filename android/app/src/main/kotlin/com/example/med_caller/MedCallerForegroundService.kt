package com.example.med_caller

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Always-on foreground service.
 *
 * Responsibilities:
 *  - Keeps the process alive (START_STICKY) so calls are detected when app is backgrounded
 *  - Owns and manages the CallReceiver registration (NOT MainActivity)
 *  - Provides a static event bridge so MainActivity can forward events to Flutter
 *    when the Flutter engine is alive, and buffers the last event when it is not
 *
 * Event flow (background):
 *   SIM call → TelephonyManager broadcast → CallReceiver (owned by this service)
 *     → onCallEvent() → if Flutter listening: forward via EventSink
 *                       else: cache last event for MainActivity to drain on resume
 *     → show overlay (TeleProvider listens on a separate EventChannel)
 */
class MedCallerForegroundService : Service() {

    private var callReceiver: CallReceiver? = null

    companion object {
        private const val TAG = "MedCallerService"
        const val CHANNEL_ID = "medcaller_bg_channel"
        const val NOTIF_ID = 1001

        // ── Static bridge between this service and the Flutter EventChannel ──────
        /**
         * Set by MainActivity when Flutter's EventChannel starts listening.
         * Cleared when Flutter cancels or Activity is destroyed.
         */
        var eventListener: ((Map<String, String>) -> Unit)? = null

        /**
         * Holds the most recent ringing event so MainActivity can replay it
         * to Flutter when the engine reconnects (e.g. user returns to app mid-ring).
         */
        var cachedRingEvent: Map<String, String>? = null

        fun start(context: Context) {
            val intent = Intent(context, MedCallerForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "Service start requested")
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, MedCallerForegroundService::class.java))
        }

        /** Called by CallReceiver whenever a telephony event fires. */
        fun onCallEvent(event: Map<String, String>) {
            Log.d(TAG, "onCallEvent: $event")

            val callEvent = event["event"] ?: ""

            if (callEvent == "RINGING") {
                cachedRingEvent = event
            } else if (callEvent == "CALL_ENDED") {
                cachedRingEvent = null
            }

            // Forward to Flutter if listening
            eventListener?.invoke(event)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        registerCallReceiver()
        Log.d(TAG, "Service created — BroadcastReceiver registered")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Re-register receiver if service was restarted by system
        if (callReceiver == null) {
            registerCallReceiver()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        unregisterCallReceiver()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
    }

    // ── Receiver lifecycle ────────────────────────────────────────────────────

    private fun registerCallReceiver() {
        if (callReceiver != null) return // already registered
        callReceiver = CallReceiver(null) // EventSink managed via static bridge
        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(callReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(callReceiver, filter)
            }
            Log.d(TAG, "CallReceiver registered in service")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register receiver: ${e.message}")
        }
    }

    private fun unregisterCallReceiver() {
        callReceiver?.let {
            runCatching { unregisterReceiver(it) }
            callReceiver = null
        }
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MedCaller Active",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps MedCaller running for incoming call identification"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            },
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MedCaller")
            .setContentText("Running in background — ready to identify callers")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
