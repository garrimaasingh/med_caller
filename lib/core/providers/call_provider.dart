import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CallState { idle, ringing, dialing, active, holding, ended }

class CallProvider extends ChangeNotifier {
  static const _stateChannel =
      EventChannel('com.medcaller.call_state_events');
  static const _controlChannel =
      MethodChannel('com.medcaller.call_control');
  static const _dialerChannel =
      MethodChannel('com.medcaller.dialer');

  StreamSubscription? _sub;

  CallState _state = CallState.idle;
  String _number = '';
  String _callerName = ''; // resolved contact/CNAM name from Android
  bool _isMuted = false;
  bool _isOnHold = false;
  bool _isSpeakerOn = false;
  bool _isDefaultDialer = false;

  CallState get state => _state;
  String get number => _number;
  String get callerName => _callerName;
  bool get isMuted => _isMuted;
  bool get isOnHold => _isOnHold;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isDefaultDialer => _isDefaultDialer;
  bool get isInCall =>
      _state == CallState.ringing ||
      _state == CallState.dialing ||
      _state == CallState.active ||
      _state == CallState.holding;

  Future<void> initialize() async {
    await checkDefaultDialer();

    _sub = _stateChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final s = event['state'] as String? ?? '';
          final n = event['number'] as String? ?? '';
          final name = event['callerName'] as String? ?? '';
          _number = n;
          _callerName = name;
          _state = _parseState(s);

          debugPrint(
            '[CallProvider] state=$s number=$n callerName=$name',
          );
          notifyListeners();
        }
      },
      onError: (e) => debugPrint('[CallProvider] EventChannel error: $e'),
    );
  }

  // ── Dialer controls ────────────────────────────────────────────────────────

  Future<void> makeCall(String number) async {
    try {
      await _dialerChannel.invokeMethod('makeCall', {'number': number});
    } catch (e) {
      debugPrint('[CallProvider] makeCall error: $e');
      rethrow;
    }
  }

  Future<void> requestDefaultDialer() async {
    await _dialerChannel.invokeMethod('requestDefaultDialer');
  }

  Future<void> checkDefaultDialer() async {
    try {
      final result =
          await _dialerChannel.invokeMethod<bool>('isDefaultDialer');
      _isDefaultDialer = result ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startBackgroundService() async {
    try {
      await _dialerChannel.invokeMethod('startService');
    } catch (e) {
      debugPrint('[CallProvider] startService error: $e');
    }
  }

  Future<void> stopBackgroundService() async {
    try {
      await _dialerChannel.invokeMethod('stopService');
    } catch (e) {
      debugPrint('[CallProvider] stopService error: $e');
    }
  }

  Future<void> requestIgnoreBatteryOptimization() async {
    try {
      await _dialerChannel.invokeMethod('ignoreBatteryOptimization');
    } catch (e) {
      debugPrint('[CallProvider] batteryOptimization error: $e');
    }
  }

  // ── In-call controls ───────────────────────────────────────────────────────

  Future<void> answerCall() async =>
      _controlChannel.invokeMethod('answerCall');

  Future<void> rejectCall() async =>
      _controlChannel.invokeMethod('rejectCall');

  Future<void> hangupCall() async =>
      _controlChannel.invokeMethod('hangupCall');

  Future<void> toggleHold() async {
    if (_isOnHold) {
      await _controlChannel.invokeMethod('unholdCall');
      _isOnHold = false;
    } else {
      await _controlChannel.invokeMethod('holdCall');
      _isOnHold = true;
    }
    notifyListeners();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _controlChannel.invokeMethod('mute', {'mute': _isMuted});
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _controlChannel.invokeMethod('toggleSpeaker', {'speaker': _isSpeakerOn});
    notifyListeners();
  }

  Future<void> playDtmf(String digit) async {
    await _controlChannel.invokeMethod('playDtmf', {'digit': digit});
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  CallState _parseState(String s) {
    switch (s) {
      case 'RINGING':    return CallState.ringing;
      case 'DIALING':    return CallState.dialing;
      case 'ACTIVE':     return CallState.active;
      case 'HOLDING':    return CallState.holding;
      case 'ENDED':      return CallState.ended;
      default:           return CallState.idle;
    }
  }

  String get stateLabel {
    switch (_state) {
      case CallState.ringing:    return 'Incoming Call';
      case CallState.dialing:    return 'Calling...';
      case CallState.active:     return 'Active Call';
      case CallState.holding:    return 'On Hold';
      case CallState.ended:      return 'Call Ended';
      default:                   return '';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
