package com.example.med_caller

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Listens for phone state changes.
 *
 * Registered by [MedCallerForegroundService] (NOT MainActivity) so it survives
 * Activity destruction. Events are routed via [MedCallerForegroundService.onCallEvent]:
 *   - If Flutter engine is alive → forwarded immediately via EventSink
 *   - Otherwise → cached for replay when the app resumes
 *
 * [legacySink] may be non-null only when used directly from MainActivity for
 * backward-compat EventChannel wiring (InCallService path). Prefer the static bridge.
 */
class CallReceiver(private val legacySink: EventChannel.EventSink? = null) : BroadcastReceiver() {

    private var lastCachedNumber = ""
    private var lastCachedName = ""

    companion object {
        private const val TAG = "CallReceiver"

        /** Strip country code / formatting to match Firestore document IDs. */
        fun normalizeNumber(raw: String): String {
            var d = raw.replace(Regex("[^0-9]"), "")
            if (d.length == 12 && d.startsWith("91")) d = d.substring(2)
            if (d.length == 11 && d.startsWith("0"))  d = d.substring(1)
            return d
        }

        /**
         * Resolve a display name for [phoneNumber] from the device address book.
         * Returns "" if READ_CONTACTS permission is not granted or no match found.
         */
        fun resolveContactName(context: Context, phoneNumber: String): String {
            if (phoneNumber.isEmpty()) return ""
            return try {
                val uri = Uri.withAppendedPath(
                    ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                    Uri.encode(phoneNumber)
                )
                var cursor: Cursor? = null
                try {
                    cursor = context.contentResolver.query(
                        uri,
                        arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME),
                        null, null, null
                    )
                    if (cursor != null && cursor.moveToFirst()) cursor.getString(0) ?: "" else ""
                } finally {
                    cursor?.close()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Contact lookup failed: ${e.message}")
                ""
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state  = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val rawNum = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        val number = if (!rawNum.isNullOrEmpty()) normalizeNumber(rawNum) else ""

        Log.d(TAG, "PhoneState=$state raw='$rawNum' normalized='$number'")

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // Update cache if we now have a number (may arrive in a second broadcast)
                if (number.isNotEmpty() && number != lastCachedNumber) {
                    lastCachedNumber = number
                    lastCachedName   = resolveContactName(context, number)
                    Log.d(TAG, "Contact resolved: '$lastCachedName'")
                }
                dispatch(
                    mapOf(
                        "event"      to "RINGING",
                        "number"     to lastCachedNumber,
                        "callerName" to lastCachedName
                    )
                )
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // Call answered — Telecom InCallService handles active-call state
                dispatch(mapOf("event" to "OFFHOOK", "number" to lastCachedNumber, "callerName" to lastCachedName))
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                dispatch(mapOf("event" to "CALL_ENDED", "number" to "", "callerName" to ""))
                lastCachedNumber = ""
                lastCachedName   = ""
            }
        }
    }

    private fun dispatch(event: Map<String, String>) {
        // Primary path: always-on service bridge
        MedCallerForegroundService.onCallEvent(event)
        // Legacy path: direct EventSink (used when receiver was wired by MainActivity)
        legacySink?.success(event)
    }
}
