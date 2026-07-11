package com.example.med_caller

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Main activity — Flutter host.
 *
 * Key architectural change: CallReceiver is NO LONGER registered here.
 * It is owned by [MedCallerForegroundService] which outlives the Activity.
 *
 * MainActivity only bridges Flutter EventChannels to the static callbacks in
 * [MedCallerForegroundService] and [CallStateManager].
 */
class MainActivity : FlutterActivity() {

    private val REQUEST_DEFAULT_DIALER = 1001

    private val CALL_DETECT_CHANNEL   = "com.medcaller.call_detection"
    private val CALL_STATE_CHANNEL    = CallStateManager.CALL_EVENT_CHANNEL
    private val CALL_CONTROL_CHANNEL  = CallStateManager.CALL_METHOD_CHANNEL
    private val DIALER_CHANNEL        = "com.medcaller.dialer"
    private val SPEECH_CHANNEL        = "com.medcaller.speech"
    private val SPEECH_EVENT_CHANNEL  = "com.medcaller.speech_events"

    private var speechRecognizer: SpeechRecognizer? = null
    private var speechEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        CallStateManager.setContext(this)

        // ── 1. Call Detection EventChannel ────────────────────────────────────
        // Connects the static bridge (service → this channel → Flutter)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_DETECT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d("MainActivity", "call_detection channel: Flutter listening")

                    // Wire the static bridge so future events from the service reach Flutter
                    MedCallerForegroundService.eventListener = { event ->
                        runOnUiThread { events?.success(event) }
                    }

                    // Replay any cached RINGING event that fired while app was closed
                    MedCallerForegroundService.cachedRingEvent?.let { cached ->
                        Log.d("MainActivity", "Replaying cached ring event: $cached")
                        runOnUiThread { events?.success(cached) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    Log.d("MainActivity", "call_detection channel: Flutter cancelled")
                    MedCallerForegroundService.eventListener = null
                }
            })

        // ── 2. Telecom call-state EventChannel (InCallService → Flutter) ──────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_STATE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    CallStateManager.setEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    CallStateManager.setEventSink(null)
                }
            })

        // ── 3. Call control MethodChannel (Flutter → Android) ─────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "answerCall" -> { CallStateManager.answerCall(); result.success(null) }
                    "rejectCall" -> { CallStateManager.rejectCall(); result.success(null) }
                    "hangupCall" -> { CallStateManager.hangupCall(); result.success(null) }
                    "holdCall"   -> { CallStateManager.holdCall();   result.success(null) }
                    "unholdCall" -> { CallStateManager.unholdCall(); result.success(null) }
                    "mute" -> {
                        val mute = call.argument<Boolean>("mute") ?: false
                        CallStateManager.muteCall(mute)
                        result.success(null)
                    }
                    "toggleSpeaker" -> {
                        val speaker = call.argument<Boolean>("speaker") ?: false
                        CallStateManager.toggleSpeaker(speaker)
                        result.success(null)
                    }
                    "playDtmf" -> {
                        val digit = call.argument<String>("digit")?.firstOrNull() ?: ' '
                        if (digit != ' ') {
                            CallStateManager.playDtmf(digit)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 4. Dialer MethodChannel (Flutter → Android) ───────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIALER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestDefaultDialer" -> {
                        requestDefaultDialer(); result.success(null)
                    }
                    "isDefaultDialer" -> {
                        result.success(isDefaultDialer())
                    }
                    "makeCall" -> {
                        val number = call.argument<String>("number") ?: ""
                        if (number.isNotEmpty()) {
                            placeCall(number); result.success(null)
                        } else {
                            result.error("INVALID_NUMBER", "Number is empty", null)
                        }
                    }
                    "startService" -> {
                        MedCallerForegroundService.start(this)
                        result.success(null)
                    }
                    "stopService" -> {
                        MedCallerForegroundService.stop(this)
                        result.success(null)
                    }
                    "ignoreBatteryOptimization" -> {
                        requestIgnoreBatteryOptimization(); result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 5. Speech-to-Text EventChannel (Android → Flutter) ───────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    speechEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    speechEventSink = null
                }
            })

        // ── 6. Speech-to-Text MethodChannel (Flutter → Android) ──────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        val available = SpeechRecognizer.isRecognitionAvailable(this)
                        result.success(available)
                    }
                    "startListening" -> {
                        startSpeechRecognition()
                        result.success(null)
                    }
                    "stopListening" -> {
                        speechRecognizer?.stopListening()
                        result.success(null)
                    }
                    "cancel" -> {
                        speechRecognizer?.cancel()
                        speechRecognizer?.destroy()
                        speechRecognizer = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Register PhoneAccount for Telecom
        registerPhoneAccount()

        // Ensure service is running whenever the activity starts
        MedCallerForegroundService.start(this)
    }

    // ── PhoneAccount ──────────────────────────────────────────────────────────

    private fun getPhoneAccountHandle() = PhoneAccountHandle(
        android.content.ComponentName(this, MedCallerConnectionService::class.java),
        "MedCallerAccount"
    )

    private fun registerPhoneAccount() {
        val telecom = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        val account = PhoneAccount.builder(getPhoneAccountHandle(), "MedCaller")
            .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
            .setSupportedUriSchemes(listOf(PhoneAccount.SCHEME_TEL))
            .build()
        telecom.registerPhoneAccount(account)
    }

    // ── Default Dialer ────────────────────────────────────────────────────────

    private fun isDefaultDialer(): Boolean {
        val telecom = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        return telecom.defaultDialerPackage == packageName
    }

    private fun requestDefaultDialer() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (!rm.isRoleHeld(RoleManager.ROLE_DIALER)) {
                startActivityForResult(
                    rm.createRequestRoleIntent(RoleManager.ROLE_DIALER),
                    REQUEST_DEFAULT_DIALER
                )
            }
        } else {
            startActivityForResult(
                Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER).apply {
                    putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
                },
                REQUEST_DEFAULT_DIALER
            )
        }
    }

    // ── Place outgoing call ───────────────────────────────────────────────────

    private fun placeCall(number: String) {
        try {
            val telecom = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val extras  = android.os.Bundle().apply {
                putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, getPhoneAccountHandle())
            }
            telecom.placeCall(Uri.fromParts("tel", number, null), extras)
        } catch (e: SecurityException) {
            startActivity(Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
        }
    }

    // ── Battery optimization ──────────────────────────────────────────────────

    private fun requestIgnoreBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                startActivity(
                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                )
            }
        }
    }

    // ── Native Speech Recognition ─────────────────────────────────────────────

    private fun startSpeechRecognition() {
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                sendSpeechEvent("status", "ready")
            }
            override fun onBeginningOfSpeech() {
                sendSpeechEvent("status", "listening")
            }
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {
                sendSpeechEvent("status", "processing")
            }
            override fun onError(error: Int) {
                val msg = when (error) {
                    SpeechRecognizer.ERROR_NETWORK -> "Network error"
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                    SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                    SpeechRecognizer.ERROR_CLIENT -> "Client error"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Missing microphone permission"
                    SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
                    SpeechRecognizer.ERROR_SERVER -> "Server error"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
                    else -> "Unknown error $error"
                }
                sendSpeechEvent("error", msg)
                // Restart after error for continuous listening
                if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                    error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                    startSpeechRecognition()
                }
            }
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull() ?: ""
                if (text.isNotBlank()) {
                    sendSpeechEvent("result", text)
                }
                // Restart for continuous listening
                startSpeechRecognition()
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull() ?: ""
                if (text.isNotBlank()) {
                    sendSpeechEvent("partial", text)
                }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        runOnUiThread { speechRecognizer?.startListening(intent) }
    }

    private fun sendSpeechEvent(type: String, value: String) {
        runOnUiThread {
            speechEventSink?.success(mapOf("type" to type, "value" to value))
        }
    }

    override fun onDestroy() {
        // Disconnect static bridge so stale references don't crash
        MedCallerForegroundService.eventListener = null
        speechRecognizer?.destroy()
        speechRecognizer = null
        super.onDestroy()
    }
}
