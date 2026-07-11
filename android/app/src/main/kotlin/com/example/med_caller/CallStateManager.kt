package com.example.med_caller

import android.content.Context
import android.telecom.Call
import android.telecom.Call.Callback
import io.flutter.plugin.common.EventChannel

/**
 * Singleton bridge: Android Telecom call lifecycle → Flutter EventChannel.
 *
 * Each event map contains:
 *   "state"      → RINGING | DIALING | ACTIVE | HOLDING | ENDED | CONNECTING
 *   "number"     → Normalized phone number (E.164 scheme-specific part)
 *   "callerName" → Caller display name from Telecom (CNAM / SIM phonebook)
 *                  or from device contacts via ContactsContract
 */
object CallStateManager {
    const val CALL_EVENT_CHANNEL = "com.medcaller.call_state_events"
    const val CALL_METHOD_CHANNEL = "com.medcaller.call_control"

    private var eventSink: EventChannel.EventSink? = null
    private var currentCall: Call? = null

    // Context stored so we can access ContentResolver for contact lookup
    private var appContext: Context? = null

    fun setContext(ctx: Context) {
        appContext = ctx.applicationContext
    }

    // Called from MedCallerInCallService when a call is added
    fun onCallAdded(call: Call) {
        currentCall = call

        call.registerCallback(object : Callback() {
            override fun onStateChanged(call: Call, state: Int) {
                notifyFlutter(eventFor(state, call))
            }
            override fun onDetailsChanged(call: Call, details: Call.Details) {
                notifyFlutter(eventFor(call.state, call))
            }
        })

        notifyFlutter(eventFor(call.state, call))
    }

    fun onCallRemoved(call: Call) {
        currentCall = null
        notifyFlutter(mapOf("state" to "ENDED", "number" to "", "callerName" to ""))
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    // ── Call controls ──────────────────────────────────────────────────────────

    fun answerCall() { currentCall?.answer(0) }
    fun rejectCall() { currentCall?.reject(false, null) }
    fun hangupCall() { currentCall?.disconnect() }

    fun holdCall() {
        if (currentCall?.details?.can(Call.Details.CAPABILITY_HOLD) == true) {
            currentCall?.hold()
        }
    }

    fun unholdCall() { currentCall?.unhold() }

    fun muteCall(mute: Boolean) {
        MedCallerInCallService.instance?.setMuted(mute)
    }

    fun toggleSpeaker(enabled: Boolean) {
        MedCallerInCallService.instance?.setSpeaker(enabled)
    }

    fun playDtmf(digit: Char) {
        currentCall?.playDtmfTone(digit)
        currentCall?.stopDtmfTone()
    }

    // ── Event building ─────────────────────────────────────────────────────────

    private fun eventFor(state: Int, call: Call): Map<String, String> {
        val stateStr = when (state) {
            Call.STATE_RINGING      -> "RINGING"
            Call.STATE_DIALING      -> "DIALING"
            Call.STATE_ACTIVE       -> "ACTIVE"
            Call.STATE_HOLDING      -> "HOLDING"
            Call.STATE_DISCONNECTED -> "ENDED"
            Call.STATE_CONNECTING   -> "CONNECTING"
            else                    -> "UNKNOWN"
        }

        val number = call.details?.handle?.schemeSpecificPart ?: ""
        val normalizedNumber = if (number.isNotEmpty())
            CallReceiver.normalizeNumber(number) else ""

        // 1. Try name from Telecom (CNAM service or SIM phonebook)
        var callerName = call.details?.callerDisplayName ?: ""

        // 2. Fall back to device contacts via ContentResolver
        if (callerName.isEmpty() && normalizedNumber.isNotEmpty() && appContext != null) {
            callerName = CallReceiver.resolveContactName(appContext!!, normalizedNumber)
        }

        return mapOf(
            "state"      to stateStr,
            "number"     to normalizedNumber,
            "callerName" to callerName
        )
    }

    private fun notifyFlutter(event: Map<String, String>) {
        eventSink?.success(event)
    }
}
