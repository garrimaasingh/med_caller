package com.example.med_caller

import android.telecom.Call
import android.telecom.InCallService
import android.telecom.CallAudioState

/**
 * InCallService is invoked by the Android Telecom stack for all SIM phone calls
 * when this app is set as the default dialer. It acts as the UI host for calls.
 */
class MedCallerInCallService : InCallService() {

    companion object {
        // Held as a weak reference so CallStateManager can call setMuted
        var instance: MedCallerInCallService? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    /**
     * Called by Telecom when a new call arrives (incoming or outgoing).
     */
    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        CallStateManager.onCallAdded(call)
    }

    /**
     * Called when a call is disconnected and removed from the stack.
     */
    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        CallStateManager.onCallRemoved(call)
    }

    fun setSpeaker(enabled: Boolean) {
        if (enabled) {
            setAudioRoute(CallAudioState.ROUTE_SPEAKER)
        } else {
            setAudioRoute(CallAudioState.ROUTE_WIRED_OR_EARPIECE)
        }
    }
}
