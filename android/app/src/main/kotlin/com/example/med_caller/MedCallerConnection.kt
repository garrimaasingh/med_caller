package com.example.med_caller

import android.telecom.Connection
import android.telecom.DisconnectCause

/**
 * Represents an individual SIM call connection.
 * Handles answer, reject, hold, unhold, mute, and disconnect.
 */
class MedCallerConnection : Connection() {

    init {
        connectionCapabilities =
            CAPABILITY_HOLD or
            CAPABILITY_SUPPORT_HOLD or
            CAPABILITY_MUTE or
            CAPABILITY_RESPOND_VIA_TEXT
    }

    override fun onAnswer() {
        super.onAnswer()
        setActive()
    }

    override fun onReject() {
        super.onReject()
        setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
        destroy()
    }

    override fun onDisconnect() {
        super.onDisconnect()
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
    }

    override fun onHold() {
        super.onHold()
        setOnHold()
    }

    override fun onUnhold() {
        super.onUnhold()
        setActive()
    }

    override fun onStateChanged(state: Int) {
        super.onStateChanged(state)
        // State changes are reflected in the InCallService callbacks
    }
}
