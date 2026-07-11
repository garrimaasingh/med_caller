package com.example.med_caller

import android.net.Uri
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager

/**
 * ConnectionService handles SIM-based outgoing and incoming calls
 * when this app is registered as the default dialer.
 */
class MedCallerConnectionService : ConnectionService() {

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val connection = MedCallerConnection()
        connection.setAddress(request?.address, TelecomManager.PRESENTATION_ALLOWED)
        connection.setDialing()
        // Transition to active after a short simulated setup
        // In practice, the SIM modem triggers state changes via TelephonyManager
        return connection
    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val connection = MedCallerConnection()
        connection.setAddress(
            request?.extras?.getParcelable(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS)
                ?: Uri.parse("tel:unknown"),
            TelecomManager.PRESENTATION_ALLOWED
        )
        connection.setRinging()
        return connection
    }

    override fun onCreateOutgoingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        // Notify Flutter of failure
        CallStateManager.setEventSink(null)
    }
}
