import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/ai_settings.dart';
import 'ai_service.dart';

/// Native Android Speech-to-Text + NVIDIA AI pipeline.
/// Uses Android's SpeechRecognizer via MethodChannel — no package dependency.
class SpeechAIService extends ChangeNotifier {
  static const _methodChannel = MethodChannel('com.medcaller.speech');
  static const _eventChannel  = EventChannel('com.medcaller.speech_events');

  final AiSettingsProvider settings;
  late final AIService _ai;

  SpeechAIService(this.settings) {
    _ai = AIService(settings);
  }

  bool _isAvailable = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _currentWords = '';
  String _statusText = '';
  final List<String> _fullTranscript = [];
  AISummaryResult? _latestResult;
  String? _lastError;

  StreamSubscription? _speechSub;
  DateTime? _lastChunkSent;
  static const _chunkInterval = Duration(seconds: 20);

  // ── Getters ──────────────────────────────────────────────────────────────────
  bool get isAvailable   => _isAvailable;
  bool get isListening   => _isListening;
  bool get isProcessing  => _isProcessing;
  String get currentWords     => _currentWords;
  String get statusText       => _statusText;
  String get fullTranscript   => _fullTranscript.join(' ');
  AISummaryResult? get latestResult => _latestResult;
  String? get lastError  => _lastError;
  bool get hasResult     => _latestResult != null;

  // ── Initialize ───────────────────────────────────────────────────────────────
  Future<bool> initialize() async {
    try {
      final available = await _methodChannel.invokeMethod<bool>('initialize') ?? false;
      _isAvailable = available;
      notifyListeners();
      return available;
    } catch (_) {
      _isAvailable = false;
      notifyListeners();
      return false;
    }
  }

  // ── Start listening ──────────────────────────────────────────────────────────
  Future<void> startListening() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _lastError = 'Microphone permission denied. Cannot listen to the call.';
      notifyListeners();
      return;
    }

    if (!_isAvailable) {
      final ok = await initialize();
      if (!ok) {
        _lastError = 'Speech recognition not available on this device';
        notifyListeners();
        return;
      }
    }

    if (!settings.isConfigured) {
      _lastError = 'API not configured. Set API key in Admin Panel → AI Settings.';
      notifyListeners();
      return;
    }

    _lastError = null;
    _lastChunkSent = DateTime.now();
    _fullTranscript.clear();
    _currentWords = '';

    _speechSub?.cancel();
    _speechSub = _eventChannel.receiveBroadcastStream().listen(
      (event) => _handleSpeechEvent(event as Map),
      onError: (e) {
        _lastError = 'Speech stream error: $e';
        _isListening = false;
        notifyListeners();
      },
    );

    await _methodChannel.invokeMethod('startListening');
    _isListening = true;
    _statusText = 'Listening...';
    notifyListeners();
  }

  // ── Handle native events ──────────────────────────────────────────────────────
  void _handleSpeechEvent(Map event) {
    final type  = event['type']  as String? ?? '';
    final value = event['value'] as String? ?? '';

    switch (type) {
      case 'status':
        _statusText = value;
        if (value == 'listening') _isListening = true;
        break;
      case 'partial':
        _currentWords = value;
        break;
      case 'result':
        if (value.trim().isNotEmpty) {
          _fullTranscript.add(value.trim());
          _currentWords = '';
          _statusText = '"${value.trim()}" captured';

          // Auto chunk every 20s
          if (_lastChunkSent != null &&
              DateTime.now().difference(_lastChunkSent!) >= _chunkInterval) {
            _lastChunkSent = DateTime.now();
            _sendChunkToAI(value);
          }
        }
        break;
      case 'error':
        _lastError = value;
        break;
    }
    notifyListeners();
  }

  // ── Stop and generate ─────────────────────────────────────────────────────────
  Future<AISummaryResult?> stopListeningAndGenerate() async {
    await _methodChannel.invokeMethod('stopListening');
    _speechSub?.cancel();
    _isListening = false;
    _statusText = '';

    if (_currentWords.trim().isNotEmpty) {
      _fullTranscript.add(_currentWords.trim());
      _currentWords = '';
    }
    notifyListeners();

    if (_fullTranscript.isEmpty) {
      _lastError = 'No speech detected. Try speaking closer to the microphone.';
      notifyListeners();
      return null;
    }
    return await _generateFromFullTranscript();
  }

  // ── Manual / Test Mode ────────────────────────────────────────────────────────
  Future<AISummaryResult?> generateFromText(String text) async {
    if (text.trim().isEmpty) {
      _lastError = 'Please enter some text first.';
      notifyListeners();
      return null;
    }
    _fullTranscript.clear();
    _fullTranscript.add(text.trim());
    return await _generateFromFullTranscript();
  }

  // ── Internal ──────────────────────────────────────────────────────────────────
  Future<void> _sendChunkToAI(String chunk) async {
    try {
      _isProcessing = true;
      notifyListeners();
      final result = await _ai.generateMedicalSummary(chunk);
      _latestResult = result;
    } catch (_) {
      // Silent — retry on final generate
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<AISummaryResult?> _generateFromFullTranscript() async {
    try {
      _isProcessing = true;
      _lastError = null;
      notifyListeners();

      final result = await _ai.generateMedicalSummary(_fullTranscript.join('\n'));
      _latestResult = result;
      notifyListeners();
      return result;
    } on AIException catch (e) {
      _lastError = '${e.title}: ${e.details}';
      notifyListeners();
      return null;
    } catch (e) {
      _lastError = 'AI Error: $e';
      notifyListeners();
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void clearTranscript() {
    _fullTranscript.clear();
    _currentWords = '';
    _latestResult = null;
    _lastError = null;
    _statusText = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _speechSub?.cancel();
    _methodChannel.invokeMethod('cancel').catchError((_) {});
    super.dispose();
  }
}
